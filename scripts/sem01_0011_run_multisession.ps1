param(
  [switch]$ValidateOnly,
  [switch]$ReadOnlyProbeOnly,
  [switch]$Execute,
  [switch]$PostcheckOnly,
  [string]$RunId
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$script:HarnessVersion = "2026-08-12-sem01-0011-multisession-v20"
$script:ExpectedPsqlVersion = "18.4"
$script:ExecutionConfirmationPhrase = "EJECUTAR SEM01 0011 EN LAB DESECHABLE"
$script:ProbeConfirmationPhrase = "SONDEAR SEM01 0011 EN LAB DESECHABLE"
$script:PostcheckConfirmationPhrase = "REVISAR SEM01 0011 EN LAB DESECHABLE"
$script:EvidenceRoot = "C:\Dev\SITAA-LOCAL-EVIDENCE\SEM-01\MULTISESSION-0011"
$script:Sem01AdvisoryKeyOne = 1397310541
$script:Sem01AdvisoryKeyTwo = 1101
$script:Sem01AdvisoryObjSubId = 2
$script:WorkerTimeoutMilliseconds = 120000
$script:ObserverTimeoutMilliseconds = 30000
$script:ObserverPollMilliseconds = 200
$script:ObserverProbeCommandTimeoutMilliseconds = 1000
$script:ObserverProbeProcessTimeoutMilliseconds = 5000
$script:RepositorySqlProcessTimeoutMilliseconds = 210000
$script:InstallationMigrationLockTimeoutMilliseconds = 5000
$script:InstallationMigrationStatementTimeoutMilliseconds = 120000
$script:InstallationWaitAgeLimitMilliseconds = 2000
$script:InstallationHolderCommitBudgetMilliseconds = 2000
$script:InstallationSafetyIntervalMilliseconds = 1000
$script:InstallationMigrationCompletionTimeoutMilliseconds = 180000
$script:InstallationHolderProcessExitTimeoutMilliseconds = 10000
$script:InstallationWaitStartDeadlineMilliseconds = 30000
$script:InstallationObserverCommandTimeoutMilliseconds = 1000
$script:InstallationServerClockRoundingToleranceMilliseconds = 2
$script:SessionIsolationMarkerSql = "select 'SESSION_DEFAULT_ISOLATION|' || pg_catalog.current_setting('default_transaction_isolation');"
$script:RepositoryFileCompletedMarkerSql = "select 'REPOSITORY_FILE_COMPLETED|1';"
$script:WallClockMarginSeconds = 45
$script:WallClockSafetyIntervalMilliseconds = 10000
$script:WallClockHolderSeconds = 70
$script:WallClockObserverTimeoutMilliseconds = 55000
$script:WallClockWorkerTimeoutMilliseconds = 90000
$script:CurrentScenario = $null
$script:TransientSqlFixtureFault = $null
$script:TransientSqlFixtureEvents = $null
$script:PsqlHandoffFixtureFault = $null
$script:Db23FixtureStartAttemptCount = 0
$script:Db23LastCreatedSqlFile = $null
$script:Db23LastHandoffState = $null
$script:Db24FixtureStartAttemptCount = 0
$script:Db24LastCreatedSqlFile = $null
$script:Db24LastHandoffState = $null
$script:Db25FixtureStartAttemptCount = 0
$script:Db25LastCreatedArtifact = $null
$script:Db25HandoffFault = $null
$script:Db25StartInfoClearFault = $null
$script:Db25ProcessIdFault = $null
$script:Db26FixtureStartAttemptCount = 0
$script:Db26WorkerTransferFault = $null
$script:Db26MonotonicTimestampQueue = $null
$script:Db26MonotonicFixtureActive = $false
$script:WorkerResults = New-Object System.Collections.ArrayList
$script:AdvisoryObservationCount = 0
$script:DeterministicOutcomeCount = 0
$script:RepositoryRoot = [System.IO.Path]::GetFullPath((Join-Path (Split-Path -Parent $PSCommandPath) ".."))
$script:CanonicalLabBoundaryPath = Join-Path $script:RepositoryRoot "scripts\b3a_matrix_run_hosted_auth_concurrency_boundaries.ps1"
$script:MigrationPath = Join-Path $script:RepositoryRoot "supabase\migrations\0011_academic_period_administration.sql"
$script:PreflightPath = Join-Path $script:RepositoryRoot "supabase\reconciliation\0011_academic_period_administration_preflight.sql"
$script:VerifierPath = Join-Path $script:RepositoryRoot "supabase\reconciliation\0011_academic_period_administration_verify.sql"
$script:RollbackPath = Join-Path $script:RepositoryRoot "supabase\reconciliation\0011_academic_period_administration_rollback.sql"
$script:ExpectedHashes = [ordered]@{
  "supabase/migrations/0011_academic_period_administration.sql" = "107e81a3af028d9c8382ef5e07ae7b2137a6aaec7ea143fa8c55d7772ad7e3c4"
  "supabase/reconciliation/0011_academic_period_administration_preflight.sql" = "c68a3c62e138e1ca789faa5b7c29cab3a295674f3fd54785a7faba716e664cdb"
  "supabase/reconciliation/0011_academic_period_administration_verify.sql" = "c3a42dcc850b87a042ea5a644a8201b19bb5e52651571781912fb1c39cdf5371"
  "supabase/reconciliation/0011_academic_period_administration_rollback.sql" = "365e2091b06e437c501bda24aaee56f2dd4dd698e4a466884ad7986743aea80e"
  "package-lock.json" = "72d151a41363c6d4f2158cc1d5a66e2ed0be9f01a691d865da78dd48cc8b23fe"
}
$script:PgEnvironmentKeys = @(
  "PGHOST", "PGHOSTADDR", "PGPORT", "PGDATABASE", "PGUSER", "PGPASSWORD",
  "PGPASSFILE", "PGSERVICE", "PGSERVICEFILE", "PGOPTIONS", "PGSSLMODE",
  "PGCONNECT_TIMEOUT", "PGAPPNAME", "PGCLIENTENCODING", "PG_COLOR"
)
$script:PhaseOrder = @(
  "PHASE_00_VALIDATE",
  "PHASE_01_READ_ONLY_BASELINE",
  "PHASE_02_INSTALLATION_MATRIX",
  "PHASE_03_ROLLBACK_MATRIX",
  "PHASE_04_REAPPLY_0011",
  "PHASE_05_RUNTIME_MATRIX",
  "PHASE_06_FINAL_POSTCHECK"
)
$script:RunStatuses = @("ready", "running", "rejected", "approved")
$script:Post0011FunctionSignatures = @(
  "is_exact_sem01_period_admin_0011(uuid)",
  "lock_and_reauthorize_sem01_admin_0011(uuid)",
  "normalize_sem01_reason_0011(text)",
  "is_sem01_audit_payload_valid_0011(text,text[],jsonb,jsonb)",
  "resolve_academic_period_proposal_0011(date,text,uuid,text,text,date,date,boolean)",
  "diagnose_academic_period_impact_0011(text,uuid,text,text,date,date,boolean)",
  "acquire_sem01_calendar_lock_0011()",
  "guard_academic_periods_sem01_0011()",
  "set_academic_period_updated_at_0011()",
  "guard_academic_period_audit_append_only_0011()",
  "get_academic_period_for_date(date)",
  "publish_activity(uuid)",
  "validate_activity_scheduled_state()",
  "list_admin_academic_periods(integer,integer)",
  "create_admin_academic_period(text,date,date,boolean)",
  "correct_admin_academic_period(uuid,text,date,date,text)",
  "activate_admin_academic_period(uuid,text)",
  "deactivate_admin_academic_period(uuid,text)"
)
$script:Post0011TriggerNames = @(
  "activities_sem01_lock_insert",
  "activities_sem01_lock_update",
  "academic_periods_guard_sem01",
  "academic_periods_guard_truncate_sem01",
  "academic_periods_set_updated_at_sem01",
  "academic_period_audit_events_guard_update_delete",
  "academic_period_audit_events_guard_truncate"
)

# BEGIN REQUIRED_SCENARIOS
$script:RequiredScenarios = @(
  [pscustomobject]@{ Ordinal = 1; Id = "MS01_PRE0011_ACTIVITY_RELATION_LOCK"; Phase = "PHASE_02_INSTALLATION_MATRIX"; Group = "installation" },
  [pscustomobject]@{ Ordinal = 2; Id = "MS02_MIGRATION_WAITS_FOR_ACTIVITIES_FIRST"; Phase = "PHASE_02_INSTALLATION_MATRIX"; Group = "installation" },
  [pscustomobject]@{ Ordinal = 3; Id = "MS03_ACTIVITY_COMMITS_BEFORE_MIGRATION_GUARD"; Phase = "PHASE_02_INSTALLATION_MATRIX"; Group = "installation" },
  [pscustomobject]@{ Ordinal = 4; Id = "MS04_INSTALLATION_NO_DEADLOCK"; Phase = "PHASE_02_INSTALLATION_MATRIX"; Group = "installation" },
  [pscustomobject]@{ Ordinal = 5; Id = "MS05_MIGRATION_PINS_READ_COMMITTED"; Phase = "PHASE_02_INSTALLATION_MATRIX"; Group = "installation" },
  [pscustomobject]@{ Ordinal = 6; Id = "MS06_ROLLBACK_PINS_READ_COMMITTED"; Phase = "PHASE_03_ROLLBACK_MATRIX"; Group = "rollback" },
  [pscustomobject]@{ Ordinal = 7; Id = "MS07_ADMIN_RPC_REJECTS_HIGH_ISOLATION"; Phase = "PHASE_05_RUNTIME_MATRIX"; Group = "isolation" },
  [pscustomobject]@{ Ordinal = 8; Id = "MS08_PUBLISH_REJECTS_HIGH_ISOLATION"; Phase = "PHASE_05_RUNTIME_MATRIX"; Group = "isolation" },
  [pscustomobject]@{ Ordinal = 9; Id = "MS09_ACTIVITY_DML_REJECTS_HIGH_ISOLATION"; Phase = "PHASE_05_RUNTIME_MATRIX"; Group = "isolation" },
  [pscustomobject]@{ Ordinal = 10; Id = "MS10_READ_COMMITTED_NORMAL_PATH"; Phase = "PHASE_05_RUNTIME_MATRIX"; Group = "isolation" },
  [pscustomobject]@{ Ordinal = 11; Id = "MS11_OVERLAPPING_CREATIONS"; Phase = "PHASE_05_RUNTIME_MATRIX"; Group = "calendar" },
  [pscustomobject]@{ Ordinal = 12; Id = "MS12_CREATE_VERSUS_CORRECTION"; Phase = "PHASE_05_RUNTIME_MATRIX"; Group = "calendar" },
  [pscustomobject]@{ Ordinal = 13; Id = "MS13_PUBLISH_VERSUS_CALENDAR"; Phase = "PHASE_05_RUNTIME_MATRIX"; Group = "activity" },
  [pscustomobject]@{ Ordinal = 14; Id = "MS14_ACTIVITY_DATE_VERSUS_CALENDAR"; Phase = "PHASE_05_RUNTIME_MATRIX"; Group = "activity" },
  [pscustomobject]@{ Ordinal = 15; Id = "MS15_ACTIVITY_RELATION_HOLDER_WAITS_ADVISORY"; Phase = "PHASE_05_RUNTIME_MATRIX"; Group = "activity" },
  [pscustomobject]@{ Ordinal = 16; Id = "MS16_CALENDAR_MUTATION_WAITS_ADVISORY"; Phase = "PHASE_05_RUNTIME_MATRIX"; Group = "activity" },
  [pscustomobject]@{ Ordinal = 17; Id = "MS17_POST_WAIT_RERESOLUTION"; Phase = "PHASE_05_RUNTIME_MATRIX"; Group = "activity" },
  [pscustomobject]@{ Ordinal = 18; Id = "MS18_PUBLISH_WALL_CLOCK_AFTER_WAIT"; Phase = "PHASE_05_RUNTIME_MATRIX"; Group = "wall_clock" },
  [pscustomobject]@{ Ordinal = 19; Id = "MS19_SCHEDULE_WALL_CLOCK_AFTER_WAIT"; Phase = "PHASE_05_RUNTIME_MATRIX"; Group = "wall_clock" },
  [pscustomobject]@{ Ordinal = 20; Id = "MS20_AUTHORITY_LOSS_AFTER_WAIT"; Phase = "PHASE_05_RUNTIME_MATRIX"; Group = "authority" },
  [pscustomobject]@{ Ordinal = 21; Id = "MS21_ADVISORY_OBSERVATION"; Phase = "PHASE_05_RUNTIME_MATRIX"; Group = "cross_cutting" },
  [pscustomobject]@{ Ordinal = 22; Id = "MS22_DETERMINISTIC_WINNER_LOSER"; Phase = "PHASE_05_RUNTIME_MATRIX"; Group = "cross_cutting" },
  [pscustomobject]@{ Ordinal = 23; Id = "MS23_RUNTIME_NO_DEADLOCK"; Phase = "PHASE_05_RUNTIME_MATRIX"; Group = "cross_cutting" },
  [pscustomobject]@{ Ordinal = 24; Id = "MS24_ZERO_RESIDUE"; Phase = "PHASE_06_FINAL_POSTCHECK"; Group = "postcheck" }
)
# END REQUIRED_SCENARIOS

function Throw-StableFailure {
  param(
    [Parameter(Mandatory = $true)][string]$Code,
    [ValidateSet(
      "expected_business_rejection", "expected_lock_rejection", "baseline_rejection",
      "connection_failure", "worker_crash", "unexpected_timeout", "postgres_deadlock",
      "postcondition_rejection", "source_integrity_rejection"
    )][string]$FailureClass = "postcondition_rejection"
  )
  $exception = New-Object System.InvalidOperationException($Code)
  $exception.Data["FailureClass"] = $FailureClass
  throw $exception
}

function Assert-Condition {
  param(
    [Parameter(Mandatory = $true)][bool]$Condition,
    [Parameter(Mandatory = $true)][string]$Code,
    [ValidateSet(
      "expected_business_rejection", "expected_lock_rejection", "baseline_rejection",
      "connection_failure", "worker_crash", "unexpected_timeout", "postgres_deadlock",
      "postcondition_rejection", "source_integrity_rejection"
    )][string]$FailureClass = "postcondition_rejection"
  )
  if (-not $Condition) {
    Throw-StableFailure -Code $Code -FailureClass $FailureClass
  }
}

function Set-CurrentScenario {
  param([Parameter(Mandatory = $true)][string]$ScenarioId)
  Assert-Condition -Condition ($ScenarioId -match '^MS(?:0[1-9]|1[0-9]|2[0-4])_[A-Z0-9_]+$') -Code "failure_scenario_rejected"
  Assert-Condition -Condition ($null -ne ($script:RequiredScenarios | Where-Object { $_.Id -eq $ScenarioId } | Select-Object -First 1)) -Code "failure_scenario_unknown"
  $script:CurrentScenario = $ScenarioId
}

function Clear-CurrentScenario {
  $script:CurrentScenario = $null
}

function Get-Sha256 {
  param([Parameter(Mandatory = $true)][string]$Path)
  return (Get-FileHash -Algorithm SHA256 -LiteralPath $Path).Hash.ToLowerInvariant()
}

function Get-TextSha256 {
  param([Parameter(Mandatory = $true)][string]$Text)
  $bytes = (New-Object System.Text.UTF8Encoding($false)).GetBytes($Text)
  $algorithm = [System.Security.Cryptography.SHA256]::Create()
  try { return ([System.BitConverter]::ToString($algorithm.ComputeHash($bytes))).Replace("-", "").ToLowerInvariant() }
  finally { $algorithm.Dispose() }
}

function Get-GitText {
  param([Parameter(Mandatory = $true)][string[]]$Arguments)
  $output = @(& git @Arguments 2>&1)
  Assert-Condition -Condition ($LASTEXITCODE -eq 0) -Code "git_command_failed"
  return ($output -join "`n").TrimEnd()
}

function Get-SourceHead {
  return Get-GitText -Arguments @("rev-parse", "HEAD")
}

function Get-RepositoryStatus {
  $text = Get-GitText -Arguments @("status", "--porcelain=v1", "--untracked-files=all")
  if ([string]::IsNullOrWhiteSpace($text)) {
    return @()
  }
  return @($text -split "`n")
}

function Assert-NoStagedFiles {
  $staged = Get-GitText -Arguments @("diff", "--cached", "--name-only")
  Assert-Condition -Condition ([string]::IsNullOrWhiteSpace($staged)) -Code "staged_files_rejected"
}

function Assert-RepositoryState {
  param([switch]$AllowPreparationDelta)
  Assert-NoStagedFiles
  $status = @(Get-RepositoryStatus)
  if (-not $AllowPreparationDelta) {
    Assert-Condition -Condition ($status.Count -eq 0) -Code "repository_not_clean"
    return
  }

  if ($status.Count -eq 0) {
    return
  }

  $allowed = @(
    "AGENTS.md",
    "package.json",
    "docs/TEST_PLAN_0011.md",
    "supabase/reconciliation/README.md",
    "scripts/sem01_0011_run_multisession.ps1",
    "scripts/check-sem01-0011-multisession.mjs"
  )
  $paths = @($status | ForEach-Object { $_.Substring(3).Replace("\", "/") })
  $unexpected = @($paths | Where-Object { $_ -notin $allowed })
  Assert-Condition -Condition ($unexpected.Count -eq 0) -Code "repository_preparation_delta_rejected"
}

function Assert-No0012Artifacts {
  $items = @(Get-ChildItem -LiteralPath $script:RepositoryRoot -Recurse -File -ErrorAction Stop |
    Where-Object { $_.Name -match '^0012(?:_|\.)' })
  Assert-Condition -Condition ($items.Count -eq 0) -Code "migration_0012_rejected"
}

function Assert-ProtectedArtifacts {
  foreach ($entry in $script:ExpectedHashes.GetEnumerator()) {
    $path = Join-Path $script:RepositoryRoot $entry.Key
    Assert-Condition -Condition (Test-Path -LiteralPath $path -PathType Leaf) -Code "protected_artifact_missing" -FailureClass "source_integrity_rejection"
    Assert-Condition -Condition ((Get-Sha256 -Path $path) -eq $entry.Value) -Code "protected_artifact_hash_rejected" -FailureClass "source_integrity_rejection"
  }
}

function Test-ProtectedArtifactsMatch {
  foreach ($entry in $script:ExpectedHashes.GetEnumerator()) {
    $path = Join-Path $script:RepositoryRoot $entry.Key
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { return $false }
    if ((Get-Sha256 -Path $path) -cne $entry.Value) { return $false }
  }
  return $true
}

function Assert-ScriptEncoding {
  param([Parameter(Mandatory = $true)][string]$Path)
  $bytes = [System.IO.File]::ReadAllBytes($Path)
  Assert-Condition -Condition ($bytes.Length -ge 3) -Code "harness_encoding_rejected"
  Assert-Condition -Condition ($bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) -Code "harness_bom_required"
  $strictUtf8 = New-Object System.Text.UTF8Encoding($false, $true)
  [void]$strictUtf8.GetString($bytes)
}

function Assert-PowerShellSyntax {
  param([Parameter(Mandatory = $true)][string]$Path)
  $tokens = $null
  $errors = $null
  [void][System.Management.Automation.Language.Parser]::ParseFile($Path, [ref]$tokens, [ref]$errors)
  Assert-Condition -Condition ($errors.Count -eq 0) -Code "powershell_parser_rejected"
}

function Assert-ScenarioContract {
  $ids = @($script:RequiredScenarios | ForEach-Object { $_.Id })
  $ordinals = @($script:RequiredScenarios | ForEach-Object { [int]$_.Ordinal })
  Assert-Condition -Condition ($ids.Count -eq 24) -Code "scenario_count_rejected"
  Assert-Condition -Condition (@($ids | Sort-Object -Unique).Count -eq 24) -Code "scenario_duplicate_rejected"
  Assert-Condition -Condition (($ordinals -join ',') -eq ((1..24) -join ',')) -Code "scenario_order_rejected"
  foreach ($id in $ids) {
    Assert-Condition -Condition ($id -match '^MS(?:0[1-9]|1[0-9]|2[0-4])_[A-Z0-9_]+$') -Code "scenario_id_rejected"
  }
  $knownPhases = @($script:PhaseOrder)
  foreach ($scenario in $script:RequiredScenarios) {
    Assert-Condition -Condition ($scenario.Phase -in $knownPhases) -Code "scenario_phase_rejected"
  }
}

function Test-ForbiddenEvidence {
  param([Parameter(Mandatory = $true)][string[]]$Lines)
  $text = $Lines -join "`n"
  $patterns = @(
    '@',
    '(?i)https?://',
    '(?i)postgres(?:ql)?://',
    '(?i)\bhostname\b',
    '(?i)\bproject[_ -]?ref(?:erence)?\b',
    '(?i)\bdatabase[_ -]?(?:name|user)\b',
    '(?i)\bpassword\b',
    '(?i)\bbearer\b',
    '(?i)\bauthorization\b',
    '(?i)\baccess[_ -]?token\b',
    '(?i)\brefresh[_ -]?token\b',
    '(?i)\bcookie\b',
    '(?i)\beyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\b',
    '\b[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}\b',
    '(?i)[A-Za-z]:\\',
    '(?i)\b(?:select|insert|update|delete|alter|drop|create|grant|revoke)\s+(?:from|into|table|function|role|schema)?\b'
  )
  foreach ($pattern in $patterns) {
    if ($text -match $pattern) {
      return $true
    }
  }
  return $false
}

function Assert-SanitizerContract {
  $safe = @(
    "HARNESS_VERSION|$($script:HarnessVersion)",
    "SOURCE_HEAD|a6f049e89f053fdc5257f017a62101fe4391be4d",
    "TARGET_CLASS|DISPOSABLE_LAB",
    "SCENARIO_ROWS|24",
    "SEM01_0011_MULTISESSION|APPROVED"
  )
  Assert-Condition -Condition (-not (Test-ForbiddenEvidence -Lines $safe)) -Code "sanitizer_safe_fixture_rejected"
  Assert-Condition -Condition (Test-ForbiddenEvidence -Lines @("VALUE|" + "https" + "://invalid.example")) -Code "sanitizer_uri_fixture_rejected"
  Assert-Condition -Condition (Test-ForbiddenEvidence -Lines @("VALUE|" + (("0" * 8) -join "") + "-0000-4000-8000-" + (("0" * 12) -join ""))) -Code "sanitizer_uuid_fixture_rejected"
  Assert-Condition -Condition (Test-ForbiddenEvidence -Lines @("VALUE|user" + "@" + "example.invalid")) -Code "sanitizer_email_fixture_rejected"
}

function Assert-ExternalEvidenceRoot {
  $root = [System.IO.Path]::GetFullPath($script:EvidenceRoot)
  $repo = $script:RepositoryRoot.TrimEnd('\') + '\'
  Assert-Condition -Condition (-not $root.StartsWith($repo, [System.StringComparison]::OrdinalIgnoreCase)) -Code "evidence_root_inside_repository"
  Assert-Condition -Condition ($root -eq "C:\Dev\SITAA-LOCAL-EVIDENCE\SEM-01\MULTISESSION-0011") -Code "evidence_root_rejected"
}

function Resolve-PsqlExecutable {
  $resolved = Get-Command "psql.exe" -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
  if ($null -eq $resolved) {
    $fallback = "C:\Program Files\PostgreSQL\18\bin\psql.exe"
    if (Test-Path -LiteralPath $fallback -PathType Leaf) {
      return $fallback
    }
    Throw-StableFailure -Code "psql_executable_required"
  }
  $path = if ($resolved.Path) { $resolved.Path } else { $resolved.Source }
  Assert-Condition -Condition (Test-Path -LiteralPath $path -PathType Leaf) -Code "psql_executable_required"
  return [System.IO.Path]::GetFullPath($path)
}

function Assert-PsqlVersion {
  param([Parameter(Mandatory = $true)][string]$PsqlPath)
  $version = @(& $PsqlPath --version 2>&1) -join ' '
  Assert-Condition -Condition ($LASTEXITCODE -eq 0) -Code "psql_version_unavailable"
  Assert-Condition -Condition ($version -match ("\b" + [regex]::Escape($script:ExpectedPsqlVersion) + "\b")) -Code "psql_version_rejected"
}

function Get-LabProjectReferenceFromCanonicalHarness {
  Assert-Condition -Condition (Test-Path -LiteralPath $script:CanonicalLabBoundaryPath -PathType Leaf) -Code "canonical_lab_boundary_missing"
  $source = [System.IO.File]::ReadAllText($script:CanonicalLabBoundaryPath, [System.Text.Encoding]::UTF8)
  $matches = [regex]::Matches($source, 'const EXPECTED_PROJECT_REF = "([a-z0-9]{20})";')
  Assert-Condition -Condition ($matches.Count -eq 1) -Code "canonical_lab_boundary_rejected"
  return $matches[0].Groups[1].Value
}

function Invoke-CredentialStateCleanup {
  param([Parameter(Mandatory = $true)][object]$CredentialState)
  return Invoke-OrchestrationCleanup -CleanupOperations @(
    [pscustomobject]@{ Name = "CONNECTION_POINTER_CLEAR"; Operation = {
      if ($CredentialState.Pointer -ne [IntPtr]::Zero) {
        [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($CredentialState.Pointer)
        $CredentialState.Pointer = [IntPtr]::Zero
        $CredentialState.PointerFreeCount++
      }
      $CredentialState.PointerFreed = $true
    } },
    [pscustomobject]@{ Name = "CONNECTION_TEXT_CLEAR"; Operation = {
      $disposeError = $null
      if ($null -ne $CredentialState.Secure -and $CredentialState.Secure -is [System.IDisposable]) {
        try { $CredentialState.Secure.Dispose() }
        catch { $disposeError = $_ }
      }
      $CredentialState.Plain = $null
      $CredentialState.Secure = $null
      $CredentialState.TextReferencesCleared = $true
      if ($null -ne $disposeError) { throw $disposeError }
    } }
  )
}

function ConvertFrom-HiddenConnectionInput {
  $credentialState = [pscustomobject]@{
    Secure = $null
    Pointer = [IntPtr]::Zero
    Plain = $null
    PointerFreed = $false
    PointerFreeCount = 0
    TextReferencesCleared = $false
  }
  $credentialState.Secure = Read-Host "URI completa del Session pooler LAB (entrada oculta)" -AsSecureString
  $connectionResult = $null
  $connectionError = $null
  $connectionScenario = $null
  try {
    $credentialState.Pointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($credentialState.Secure)
    $credentialState.Plain = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($credentialState.Pointer)
    Assert-Condition -Condition (-not [string]::IsNullOrWhiteSpace($credentialState.Plain)) -Code "database_connection_input_rejected"
    try {
      $uri = [Uri]$credentialState.Plain
    }
    catch {
      Throw-StableFailure -Code "database_connection_input_rejected"
    }

    $expectedReference = Get-LabProjectReferenceFromCanonicalHarness
    $boundary = Assert-LabConnectionBoundary -Uri $uri -ExpectedReference $expectedReference

    $connectionResult = [pscustomobject]@{
      Host = $boundary.Host
      Port = "5432"
      User = $boundary.User
      Password = $boundary.Password
      Database = "postgres"
      SslMode = $boundary.SslMode
      Classification = "DISPOSABLE_LAB"
    }
  }
  catch {
    $connectionError = $_
    $connectionScenario = [string]$script:CurrentScenario
  }
  $credentialCleanup = Invoke-CredentialStateCleanup -CredentialState $credentialState
  Complete-OrchestrationCleanup -PrimaryError $connectionError -PrimaryScenario $connectionScenario -CleanupResult $credentialCleanup `
    -CleanupFailureCode "database_connection_cleanup_rejected"
  Assert-Condition -Condition ($null -ne $connectionResult -and $credentialState.Pointer -eq [IntPtr]::Zero -and
    $credentialState.PointerFreed -and $credentialState.PointerFreeCount -eq 1 -and $null -eq $credentialState.Plain -and
    $null -eq $credentialState.Secure -and $credentialState.TextReferencesCleared) `
    -Code "database_connection_cleanup_postcondition_rejected"
  return $connectionResult
}

function Assert-LabConnectionBoundary {
  param(
    [Parameter(Mandatory = $true)][Uri]$Uri,
    [Parameter(Mandatory = $true)][string]$ExpectedReference
  )
  Assert-Condition -Condition ($Uri.Scheme -in @("postgres", "postgresql")) -Code "database_connection_input_rejected"
  Assert-Condition -Condition ($Uri.Port -eq 5432) -Code "session_pooler_port_rejected"
  Assert-Condition -Condition ($Uri.AbsolutePath -ceq "/postgres") -Code "database_name_rejected"
  Assert-Condition -Condition ([string]::IsNullOrEmpty($Uri.Fragment)) -Code "database_connection_fragment_rejected"
  Assert-Condition -Condition ($Uri.Host -cmatch '^[a-z0-9-]+(?:\.[a-z0-9-]+)*\.pooler\.supabase\.com$') -Code "session_pooler_hostname_rejected"

  $userInfo = $Uri.UserInfo.Split(':', 2)
  Assert-Condition -Condition ($userInfo.Count -eq 2) -Code "database_connection_input_rejected"
  $username = [Uri]::UnescapeDataString($userInfo[0])
  $password = [Uri]::UnescapeDataString($userInfo[1])
  Assert-Condition -Condition ($username -ceq ("postgres." + $ExpectedReference)) -Code "disposable_lab_username_rejected"
  Assert-Condition -Condition (-not [string]::IsNullOrWhiteSpace($password)) -Code "database_connection_input_rejected"

  $query = $Uri.Query.TrimStart('?')
  $sslMode = "require"
  if (-not [string]::IsNullOrWhiteSpace($query)) {
    $parts = @($query -split '&')
    Assert-Condition -Condition ($parts.Count -eq 1 -and $parts[0] -cmatch '^sslmode=(require|verify-ca|verify-full)$') -Code "database_connection_query_rejected"
    $sslMode = $Matches[1]
  }
  return [pscustomobject]@{ Host = $Uri.Host; User = $username; Password = $password; SslMode = $sslMode }
}

function Assert-TargetBoundaryContract {
  $reference = Get-LabProjectReferenceFromCanonicalHarness
  $valid = [Uri]("postgresql://postgres." + $reference + ":fixture@aws-0-test-1.pooler.supabase.com:5432/postgres?sslmode=require")
  [void](Assert-LabConnectionBoundary -Uri $valid -ExpectedReference $reference)
  $rejected = @(
    "postgresql://postgres.$reference`:fixture@host-$reference.evil.invalid:5432/postgres?sslmode=require",
    "postgresql://prefix-postgres.$reference`:fixture@aws-0-test-1.pooler.supabase.com:5432/postgres?sslmode=require",
    "postgresql://postgres.$reference-suffix`:fixture@aws-0-test-1.pooler.supabase.com:5432/postgres?sslmode=require",
    "postgresql://postgres.$reference`:fixture@$reference.supabase.co:5432/postgres?sslmode=require",
    "postgresql://postgres.$reference`:fixture@pooler.supabase.com.evil.invalid:5432/postgres?sslmode=require",
    "postgresql://postgres.$reference`:fixture@aws-0-test-1.pooler.supabase.com:6543/postgres?sslmode=require",
    "postgresql://postgres.$reference`:fixture@aws-0-test-1.pooler.supabase.com:5432/other?sslmode=require",
    "postgresql://postgres.$reference`:fixture@aws-0-test-1.pooler.supabase.com:5432/postgres?sslmode=require&application_name=bad"
  )
  foreach ($candidate in $rejected) {
    $wasRejected = $false
    try { [void](Assert-LabConnectionBoundary -Uri ([Uri]$candidate) -ExpectedReference $reference) }
    catch { $wasRejected = $true }
    Assert-Condition -Condition $wasRejected -Code "target_boundary_negative_fixture_rejected"
  }
}

function Clear-ConnectionMaterial {
  param([AllowNull()][object]$Connection)
  if ($null -eq $Connection) { return }
  foreach ($name in @("Password", "User", "Host", "Database")) {
    try {
      if (Test-ObjectProperty -Value $Connection -Name $name) {
        $Connection.PSObject.Properties[$name].Value = $null
      }
    }
    catch { }
  }
}

function Quote-ProcessArgument {
  param([Parameter(Mandatory = $true)][string]$Value)
  return '"' + $Value.Replace('"', '\"') + '"'
}

function New-CanonicalEnvironmentProcessStartInfo {
  $seen = @{}
  $removed = New-Object System.Collections.ArrayList
  foreach ($entry in @([System.Environment]::GetEnvironmentVariables().GetEnumerator() | Sort-Object { [string]$_.Key })) {
    $key = [string]$entry.Key
    $canonicalKey = $key.ToUpperInvariant()
    if ($seen.ContainsKey($canonicalKey)) {
      [void]$removed.Add([pscustomobject]@{ Key = $key; Value = [string]$entry.Value })
      [System.Environment]::SetEnvironmentVariable($key, $null, [System.EnvironmentVariableTarget]::Process)
    }
    else { $seen[$canonicalKey] = $true }
  }
  $environmentError = $null
  $environmentScenario = $null
  $info = $null
  try {
    $info = New-Object System.Diagnostics.ProcessStartInfo
    [void]$info.EnvironmentVariables.Count
  }
  catch {
    $environmentError = $_
    $environmentScenario = [string]$script:CurrentScenario
  }
  $restoreOperations = @($removed | ForEach-Object {
    $entry = $_
    $restoreOperation = {
      [System.Environment]::SetEnvironmentVariable([string]$entry.Key, [string]$entry.Value, [System.EnvironmentVariableTarget]::Process)
    }.GetNewClosure()
    [pscustomobject]@{ Name = "PROCESS_ENVIRONMENT_RESTORE"; Operation = $restoreOperation }
  })
  $environmentCleanup = Invoke-OrchestrationCleanup -CleanupOperations $restoreOperations
  Complete-OrchestrationCleanup -PrimaryError $environmentError -PrimaryScenario $environmentScenario -CleanupResult $environmentCleanup `
    -CleanupFailureCode "process_environment_cleanup_rejected"
  Assert-Condition -Condition ($null -ne $info) -Code "process_environment_start_info_rejected"
  return $info
}

function ConvertTo-PgOptionsValue {
  param([Parameter(Mandatory = $true)][string]$Value)
  Assert-Condition -Condition ($Value -notmatch '[\r\n\t\x00''"]') -Code "pgoptions_value_control_character_rejected" -FailureClass "source_integrity_rejection"
  Assert-Condition -Condition ($Value -notmatch '(^|\s)-') -Code "pgoptions_value_option_like_rejected" -FailureClass "source_integrity_rejection"
  Assert-Condition -Condition ($Value -cin @("read committed", "repeatable read")) -Code "pgoptions_isolation_rejected" -FailureClass "source_integrity_rejection"
  return $Value.Replace('\', '\\').Replace(' ', '\ ')
}

function New-PsqlStartInfo {
  param(
    [Parameter(Mandatory = $true)][string]$PsqlPath,
    [Parameter(Mandatory = $true)][object]$Connection,
    [Parameter(Mandatory = $true)][string]$SqlFile,
    [Parameter(Mandatory = $true)][string]$ApplicationName,
    [int]$StatementTimeoutMilliseconds = 45000,
    [int]$LockTimeoutMilliseconds = 15000,
    [ValidateSet("read committed", "repeatable read")][string]$DefaultIsolation = "read committed",
    [switch]$EmitSessionIsolationMarker,
    [switch]$EmitRepositoryFileCompletedMarker
  )
  Assert-Condition -Condition ($ApplicationName -match '^sitaa_sem01_[a-z0-9_]{1,48}$') -Code "application_name_rejected"
  $info = New-CanonicalEnvironmentProcessStartInfo
  $info.FileName = $PsqlPath
  $info.Arguments = "-X -qAt -w -v ON_ERROR_STOP=1 -v VERBOSITY=verbose"
  if ($EmitSessionIsolationMarker) {
    $info.Arguments += " -c " + (Quote-ProcessArgument -Value $script:SessionIsolationMarkerSql)
  }
  $info.Arguments += " -f " + (Quote-ProcessArgument -Value $SqlFile)
  if ($EmitRepositoryFileCompletedMarker) {
    $info.Arguments += " -c " + (Quote-ProcessArgument -Value $script:RepositoryFileCompletedMarkerSql)
  }
  $info.UseShellExecute = $false
  $info.CreateNoWindow = $true
  $info.RedirectStandardOutput = $true
  $info.RedirectStandardError = $true
  foreach ($key in $script:PgEnvironmentKeys) {
    [void]$info.EnvironmentVariables.Remove($key)
  }
  $info.EnvironmentVariables["PGHOST"] = $Connection.Host
  $info.EnvironmentVariables["PGPORT"] = $Connection.Port
  $info.EnvironmentVariables["PGUSER"] = $Connection.User
  $info.EnvironmentVariables["PGPASSWORD"] = $Connection.Password
  $info.EnvironmentVariables["PGDATABASE"] = $Connection.Database
  $info.EnvironmentVariables["PGSSLMODE"] = $Connection.SslMode
  $info.EnvironmentVariables["PGCONNECT_TIMEOUT"] = "10"
  $info.EnvironmentVariables["PGCLIENTENCODING"] = "UTF8"
  $info.EnvironmentVariables["PG_COLOR"] = "never"
  $info.EnvironmentVariables["PGAPPNAME"] = $ApplicationName
  $encodedIsolation = ConvertTo-PgOptionsValue -Value $DefaultIsolation
  $info.EnvironmentVariables["PGOPTIONS"] = "-c statement_timeout=$StatementTimeoutMilliseconds -c lock_timeout=$LockTimeoutMilliseconds -c default_transaction_isolation=$encodedIsolation"
  return $info
}

function New-StagedPsqlStartInfo {
  param(
    [Parameter(Mandatory = $true)][string]$PsqlPath,
    [Parameter(Mandatory = $true)][object]$Connection,
    [Parameter(Mandatory = $true)][string]$ApplicationName,
    [int]$StatementTimeoutMilliseconds = 45000,
    [int]$LockTimeoutMilliseconds = 15000,
    [switch]$ReadOnly
  )
  $stdinSentinel = "sitaa-sem01-controller-stdin.sql"
  $info = New-PsqlStartInfo -PsqlPath $PsqlPath -Connection $Connection -SqlFile $stdinSentinel -ApplicationName $ApplicationName `
    -StatementTimeoutMilliseconds $StatementTimeoutMilliseconds -LockTimeoutMilliseconds $LockTimeoutMilliseconds
  $fileSuffix = " -f " + (Quote-ProcessArgument -Value $stdinSentinel)
  Assert-Condition -Condition ($info.Arguments.EndsWith($fileSuffix, [System.StringComparison]::Ordinal)) -Code "staged_psql_argument_contract_rejected" -FailureClass "source_integrity_rejection"
  $info.Arguments = $info.Arguments.Substring(0, $info.Arguments.Length - $fileSuffix.Length)
  $info.RedirectStandardInput = $true
  if ($ReadOnly) {
    $info.EnvironmentVariables["PGOPTIONS"] += " -c default_transaction_read_only=on"
  }
  return $info
}

function Clear-ChildPgEnvironment {
  param([Parameter(Mandatory = $true)][System.Diagnostics.ProcessStartInfo]$StartInfo)
  foreach ($key in $script:PgEnvironmentKeys) {
    if ($StartInfo.EnvironmentVariables.ContainsKey($key)) {
      [void]$StartInfo.EnvironmentVariables.Remove($key)
    }
  }
}

function Test-PsqlStartInfoContainsPgMaterial {
  param([AllowNull()][System.Diagnostics.ProcessStartInfo]$StartInfo)
  if ($null -eq $StartInfo) { return $false }
  foreach ($key in $script:PgEnvironmentKeys) {
    if ($StartInfo.EnvironmentVariables.ContainsKey($key)) { return $true }
  }
  return $false
}

function Clear-PsqlStartInfoMaterial {
  param(
    [Parameter(Mandatory = $true)][object]$State,
    [Parameter(Mandatory = $true)][System.Diagnostics.ProcessStartInfo]$StartInfo
  )
  $State.StartInfoMaterialClearAttempted = $true
  if ($ValidateOnly -and $script:Db25StartInfoClearFault -ceq "failure") {
    Throw-StableFailure -Code "db25_start_info_clear_failure" -FailureClass "postcondition_rejection"
  }
  Clear-ChildPgEnvironment -StartInfo $StartInfo
  Assert-Condition -Condition (-not (Test-PsqlStartInfoContainsPgMaterial -StartInfo $StartInfo)) `
    -Code "psql_start_info_material_retained" -FailureClass "postcondition_rejection"
  $State.StartInfoMaterialCleared = $true
}

function Invoke-ExternalFileStateCleanup {
  param([Parameter(Mandatory = $true)][object]$FileState)
  return Invoke-OrchestrationCleanup -CleanupOperations @(
    [pscustomobject]@{ Name = "EXTERNAL_WRITER_DISPOSE"; Operation = {
      if ($FileState.WriterOwned -and $null -ne $FileState.Writer) {
        $disposeError = $null
        try { $FileState.Writer.Dispose() }
        catch { $disposeError = $_ }
        $FileState.Writer = $null
        if ($null -eq $disposeError) { $FileState.WriterDisposed = $true }
        else { throw $disposeError }
      }
    } },
    [pscustomobject]@{ Name = "EXTERNAL_STREAM_DISPOSE"; Operation = {
      if ($FileState.StreamOwned -and $null -ne $FileState.Stream) {
        $disposeError = $null
        try { $FileState.Stream.Dispose() }
        catch { $disposeError = $_ }
        $FileState.Stream = $null
        if ($null -eq $disposeError) { $FileState.StreamDisposed = $true }
        else { throw $disposeError }
      }
    } }
  )
}

function Invoke-ExclusiveExternalFileWrite {
  param(
    [Parameter(Mandatory = $true)][string]$FullPath,
    [Parameter(Mandatory = $true)][string]$Content,
    [Parameter(Mandatory = $true)][System.Text.Encoding]$Encoding
  )
  $fileState = [pscustomobject]@{
    Stream = $null
    Writer = $null
    StreamOwned = $false
    WriterOwned = $false
    WriterDisposed = $false
    StreamDisposed = $false
  }
  $writeError = $null
  $writeScenario = $null
  try {
    $fileState.Stream = New-Object System.IO.FileStream($FullPath, [System.IO.FileMode]::CreateNew, [System.IO.FileAccess]::Write, [System.IO.FileShare]::None)
    $fileState.StreamOwned = $true
    $fileState.Writer = New-Object System.IO.StreamWriter($fileState.Stream, $Encoding)
    $fileState.WriterOwned = $true
    $fileState.Writer.Write($Content)
    $fileState.Writer.Flush()
  }
  catch {
    $writeError = $_
    $writeScenario = [string]$script:CurrentScenario
  }
  $writeCleanup = Invoke-ExternalFileStateCleanup -FileState $fileState
  Complete-OrchestrationCleanup -PrimaryError $writeError -PrimaryScenario $writeScenario -CleanupResult $writeCleanup `
    -CleanupFailureCode "external_file_cleanup_rejected"
  Assert-Condition -Condition ($null -eq $fileState.Writer -and $null -eq $fileState.Stream -and
    (-not $fileState.WriterOwned -or $fileState.WriterDisposed) -and
    (-not $fileState.StreamOwned -or $fileState.StreamDisposed) -and
    (Test-Path -LiteralPath $FullPath -PathType Leaf)) -Code "external_file_cleanup_postcondition_rejected"
  return $fileState
}

function Write-ExternalUtf8File {
  param(
    [Parameter(Mandatory = $true)][string]$Path,
    [Parameter(Mandatory = $true)][string]$Content,
    [switch]$Exclusive
  )
  $full = [System.IO.Path]::GetFullPath($Path)
  $root = [System.IO.Path]::GetFullPath($script:EvidenceRoot).TrimEnd('\') + '\'
  Assert-Condition -Condition ($full.StartsWith($root, [System.StringComparison]::OrdinalIgnoreCase)) -Code "external_file_path_rejected"
  $encoding = New-Object System.Text.UTF8Encoding($false)
  if ($Exclusive) {
    [void](Invoke-ExclusiveExternalFileWrite -FullPath $full -Content $Content -Encoding $encoding)
  }
  else {
    [System.IO.File]::WriteAllText($full, $Content, $encoding)
  }
}

function New-RunPaths {
  param([Parameter(Mandatory = $true)][string]$Identifier)
  Assert-Condition -Condition ($Identifier -match '^[0-9]{8}T[0-9]{6}Z-[a-f0-9]{8}$') -Code "run_id_rejected"
  $runDirectory = Join-Path $script:EvidenceRoot $Identifier
  return [pscustomobject]@{
    Root = $runDirectory
    Manifest = Join-Path $runDirectory "run-manifest.local.json"
    Evidence = Join-Path $runDirectory "multisession-evidence.local.txt"
    Failure = Join-Path $runDirectory "multisession-failure.local.txt"
    FinalPostcheck = Join-Path $runDirectory "final-postcheck.local.txt"
    FailurePostcheck = Join-Path $runDirectory "failure-postcheck.local.txt"
    WorkerManifest = Join-Path $runDirectory "worker-pids.local.json"
  }
}

function Get-TerminalMarkerCount {
  param(
    [Parameter(Mandatory = $true)][string]$Path,
    [Parameter(Mandatory = $true)][string]$Marker
  )
  if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return 0 }
  return @((Get-Content -LiteralPath $Path -Encoding utf8) | Where-Object { [string]$_ -ceq $Marker }).Count
}

function Get-TerminalArtifactInventory {
  param([Parameter(Mandatory = $true)][object]$Paths)
  $approvedPostcheckPublishing = Test-Path -LiteralPath ($Paths.FinalPostcheck + ".publishing") -PathType Leaf
  $approvedEvidencePublishing = Test-Path -LiteralPath ($Paths.Evidence + ".publishing") -PathType Leaf
  $failurePostcheckPublishing = Test-Path -LiteralPath ($Paths.FailurePostcheck + ".publishing") -PathType Leaf
  $rejectedEvidencePublishing = Test-Path -LiteralPath ($Paths.Failure + ".publishing") -PathType Leaf
  $finalPostcheckExists = Test-Path -LiteralPath $Paths.FinalPostcheck -PathType Leaf
  $failurePostcheckExists = Test-Path -LiteralPath $Paths.FailurePostcheck -PathType Leaf
  return [pscustomobject]@{
    ApprovedPostcheckExists = $finalPostcheckExists
    ApprovedPostcheckMarkerValid = ($finalPostcheckExists -and (Get-TerminalMarkerCount -Path $Paths.FinalPostcheck -Marker "FINAL_POSTCHECK|APPROVED") -eq 1 -and (Get-TerminalMarkerCount -Path $Paths.FinalPostcheck -Marker "FAILURE_POSTCHECK|RECORDED") -eq 0)
    ApprovedEvidenceExists = (Test-Path -LiteralPath $Paths.Evidence -PathType Leaf)
    FailurePostcheckExists = $failurePostcheckExists
    FailurePostcheckMarkerValid = ($failurePostcheckExists -and (Get-TerminalMarkerCount -Path $Paths.FailurePostcheck -Marker "FAILURE_POSTCHECK|RECORDED") -eq 1 -and (Get-TerminalMarkerCount -Path $Paths.FailurePostcheck -Marker "FINAL_POSTCHECK|APPROVED") -eq 0)
    RejectedEvidenceExists = (Test-Path -LiteralPath $Paths.Failure -PathType Leaf)
    ApprovedPostcheckPublishing = $approvedPostcheckPublishing
    ApprovedEvidencePublishing = $approvedEvidencePublishing
    FailurePostcheckPublishing = $failurePostcheckPublishing
    RejectedEvidencePublishing = $rejectedEvidencePublishing
    TotalPublishingArtifacts = [int]$approvedPostcheckPublishing + [int]$approvedEvidencePublishing + [int]$failurePostcheckPublishing + [int]$rejectedEvidencePublishing
  }
}

function Test-ApprovedFinalizationStarted {
  param([Parameter(Mandatory = $true)][object]$Inventory)
  return [bool]($Inventory.ApprovedPostcheckExists -or $Inventory.ApprovedEvidenceExists -or $Inventory.ApprovedPostcheckPublishing -or $Inventory.ApprovedEvidencePublishing)
}

function Get-TerminalArtifactClassification {
  param(
    [Parameter(Mandatory = $true)][object]$Inventory,
    [Parameter(Mandatory = $true)][ValidateSet("ready", "running", "rejected", "approved")][string]$RunStatus
  )
  $approvedPublishing = [bool]($Inventory.ApprovedPostcheckPublishing -or $Inventory.ApprovedEvidencePublishing)
  $rejectedPublishing = [bool]($Inventory.FailurePostcheckPublishing -or $Inventory.RejectedEvidencePublishing)
  $approvedSide = [bool]($Inventory.ApprovedPostcheckExists -or $Inventory.ApprovedEvidenceExists -or $approvedPublishing)
  $rejectedSide = [bool]($Inventory.FailurePostcheckExists -or $Inventory.RejectedEvidenceExists -or $rejectedPublishing)
  $invalidMarker = [bool](($Inventory.ApprovedPostcheckExists -and -not $Inventory.ApprovedPostcheckMarkerValid) -or ($Inventory.FailurePostcheckExists -and -not $Inventory.FailurePostcheckMarkerValid))
  $stableCode = if ($approvedSide -and $rejectedSide) { "ambiguous_terminal_artifacts" }
    elseif ($approvedPublishing) { "approval_publication_incomplete" }
    elseif ($rejectedPublishing) { "rejection_publication_incomplete" }
    elseif ($invalidMarker) { "ambiguous_terminal_artifacts" }
    elseif ($approvedSide -and $RunStatus -cne "approved") { "approval_finalization_incomplete" }
    elseif ($rejectedSide -and $RunStatus -cne "rejected") { "rejection_finalization_incomplete" }
    else { $null }
  $contractMatches = if ($null -ne $stableCode) { $false }
    elseif ($RunStatus -ceq "approved") {
      $Inventory.ApprovedEvidenceExists -and $Inventory.ApprovedPostcheckExists -and $Inventory.ApprovedPostcheckMarkerValid -and
        -not $Inventory.FailurePostcheckExists -and -not $Inventory.RejectedEvidenceExists -and $Inventory.TotalPublishingArtifacts -eq 0
    }
    elseif ($RunStatus -ceq "rejected") {
      $Inventory.RejectedEvidenceExists -and -not $Inventory.ApprovedEvidenceExists -and -not $Inventory.ApprovedPostcheckExists -and
        (-not $Inventory.FailurePostcheckExists -or $Inventory.FailurePostcheckMarkerValid) -and $Inventory.TotalPublishingArtifacts -eq 0
    }
    else {
      -not $approvedSide -and -not $rejectedSide -and $Inventory.TotalPublishingArtifacts -eq 0
    }
  return [pscustomobject]@{ StableCode = $stableCode; EvidenceContractMatches = [bool]$contractMatches }
}

function Invoke-SecondaryFailureOperation {
  param([Parameter(Mandatory = $true)][scriptblock]$Operation)
  # Las propiedades de objetos compartidos sí se propagan; las asignaciones escalares quedan en el scope hijo de &.
  # Si un caller necesita un escalar, debe consumir Operation.Value y asignarlo en su propio scope.
  try { return [pscustomobject]@{ Succeeded = $true; Value = (& $Operation); SecondaryError = $null } }
  catch { return [pscustomobject]@{ Succeeded = $false; Value = $null; SecondaryError = "secondary_finalization_error" } }
}

function Invoke-OrchestrationCleanup {
  param(
    [AllowEmptyCollection()][object[]]$CleanupOperations = @(),
    [switch]$EmitFailureMarkers
  )
  $secondaryErrors = New-Object System.Collections.ArrayList
  foreach ($cleanupOperation in @($CleanupOperations)) {
    $name = if ($null -ne $cleanupOperation -and (Test-ObjectProperty -Value $cleanupOperation -Name "Name") -and
      [string]$cleanupOperation.Name -cmatch '^[A-Z0-9_]+$') { [string]$cleanupOperation.Name } else { "INVALID_CLEANUP" }
    $operation = if ($null -ne $cleanupOperation -and (Test-ObjectProperty -Value $cleanupOperation -Name "Operation") -and
      $cleanupOperation.Operation -is [scriptblock]) { [scriptblock]$cleanupOperation.Operation } else { $null }
    $result = if ($null -ne $operation) {
      Invoke-SecondaryFailureOperation -Operation $operation
    }
    else {
      [pscustomobject]@{ Succeeded = $false; Value = $null; SecondaryError = "secondary_finalization_error" }
    }
    if (-not $result.Succeeded) {
      [void]$secondaryErrors.Add($name)
      if ($EmitFailureMarkers) { Write-Warning ("SECONDARY_CLEANUP|" + $name + "|FAILED") }
    }
  }
  return [pscustomobject]@{
    Succeeded = ($secondaryErrors.Count -eq 0)
    SecondaryErrors = @($secondaryErrors)
  }
}

function Complete-OrchestrationCleanup {
  param(
    [AllowNull()][System.Management.Automation.ErrorRecord]$PrimaryError,
    [AllowNull()][string]$PrimaryScenario,
    [Parameter(Mandatory = $true)][object]$CleanupResult,
    [Parameter(Mandatory = $true)][string]$CleanupFailureCode
  )
  if ($null -ne $PrimaryError) {
    $script:CurrentScenario = $PrimaryScenario
    throw $PrimaryError
  }
  Assert-Condition -Condition ($CleanupResult.Succeeded -and @($CleanupResult.SecondaryErrors).Count -eq 0) `
    -Code $CleanupFailureCode -FailureClass "postcondition_rejection"
}

function Get-FailureScenario {
  if ($null -eq $script:CurrentScenario) { return "NONE" }
  Assert-Condition -Condition ([string]$script:CurrentScenario -in @($script:RequiredScenarios | ForEach-Object { $_.Id })) -Code "failure_scenario_unknown"
  return [string]$script:CurrentScenario
}

function New-RunIdentifier {
  $stamp = [DateTime]::UtcNow.ToString("yyyyMMdd'T'HHmmss'Z'")
  $suffix = [guid]::NewGuid().ToString("N").Substring(0, 8)
  return "$stamp-$suffix"
}

function Write-Manifest {
  param(
    [Parameter(Mandatory = $true)][object]$Paths,
    [Parameter(Mandatory = $true)][object]$Manifest
  )
  $json = $Manifest | ConvertTo-Json -Depth 8
  $temporary = $Paths.Manifest + ".next"
  Write-ExternalUtf8File -Path $temporary -Content ($json + "`n")
  Move-Item -LiteralPath $temporary -Destination $Paths.Manifest -Force
}

function Copy-ManifestRecord {
  param([Parameter(Mandatory = $true)][object]$Manifest)
  return (($Manifest | ConvertTo-Json -Depth 16 -Compress) | ConvertFrom-Json)
}

function Get-PhaseIndex {
  param([Parameter(Mandatory = $true)][string]$Phase)
  if ($Phase -ceq "NONE") { return -1 }
  return [array]::IndexOf($script:PhaseOrder, $Phase)
}

function Get-NextRemotePhaseIndex {
  param([Parameter(Mandatory = $true)][string]$CompletedPhase)
  $completedIndex = Get-PhaseIndex -Phase $CompletedPhase
  if ($completedIndex -lt 1) { return (Get-PhaseIndex -Phase "PHASE_01_READ_ONLY_BASELINE") }
  return $completedIndex + 1
}

function Get-ScenarioIdsThroughPhase {
  param([Parameter(Mandatory = $true)][string]$Phase)
  $phaseIndex = Get-PhaseIndex -Phase $Phase
  return @($script:RequiredScenarios |
    Where-Object { (Get-PhaseIndex -Phase ([string]$_.Phase)) -le $phaseIndex } |
    Sort-Object Ordinal |
    ForEach-Object { [string]$_.Id })
}

function Get-ScenarioIdsForPhase {
  param([Parameter(Mandatory = $true)][string]$Phase)
  return @($script:RequiredScenarios |
    Where-Object { [string]$_.Phase -ceq $Phase } |
    Sort-Object Ordinal |
    ForEach-Object { [string]$_.Id })
}

function Get-AssertionProperties {
  param([Parameter(Mandatory = $true)][object]$Assertions)
  if ($Assertions -is [System.Collections.IDictionary]) {
    return @($Assertions.GetEnumerator() | ForEach-Object {
      [pscustomobject]@{ Name = [string]$_.Key; Value = $_.Value }
    })
  }
  return @($Assertions.PSObject.Properties | ForEach-Object {
    [pscustomobject]@{ Name = [string]$_.Name; Value = $_.Value }
  })
}

function Get-ExpectedStateForCompletedPhase {
  param([Parameter(Mandatory = $true)][string]$Phase)
  if ($Phase -in @("PHASE_02_INSTALLATION_MATRIX", "PHASE_04_REAPPLY_0011", "PHASE_05_RUNTIME_MATRIX", "PHASE_06_FINAL_POSTCHECK")) { return "POST0011" }
  return "POST0010"
}

function Test-NonnegativeInteger {
  param([AllowNull()][object]$Value)
  return ($Value -is [byte] -or $Value -is [int16] -or $Value -is [int32] -or $Value -is [int64] -or
    $Value -is [uint16] -or $Value -is [uint32] -or $Value -is [uint64]) -and [decimal]$Value -ge 0
}

function Test-PositiveInteger {
  param([AllowNull()][object]$Value)
  return (Test-NonnegativeInteger -Value $Value) -and [decimal]$Value -gt 0
}

function Test-LowercaseSha256 {
  param([AllowNull()][object]$Value)
  return $Value -is [string] -and $Value -cmatch '^[0-9a-f]{64}$'
}

function Test-LowercaseMd5 {
  param([AllowNull()][object]$Value)
  return $Value -is [string] -and $Value -cmatch '^[0-9a-f]{32}$'
}

function Get-ExpectedDiagnosticCountsForPhase {
  param([Parameter(Mandatory = $true)][string]$Phase)
  $activities = if ($Phase -ceq "PHASE_02_INSTALLATION_MATRIX") { 1 } else { 0 }
  return [ordered]@{
    FixturePeriods = 0
    Activities = $activities
    AuditEvents = 0
    OpenWorkers = 0
    GrantedSem01AdvisoryLocks = 0
    WaitingSem01AdvisoryLocks = 0
    TotalSem01AdvisoryLocks = 0
    TransientWorkerSqlFiles = 0
    TemporaryObjects = 0
  }
}

function Assert-ExpectedDiagnosticCountsShape {
  param([Parameter(Mandatory = $true)][object]$Counts)
  $expectedKeys = @(
    "FixturePeriods", "Activities", "AuditEvents", "OpenWorkers", "GrantedSem01AdvisoryLocks",
    "WaitingSem01AdvisoryLocks", "TotalSem01AdvisoryLocks", "TransientWorkerSqlFiles", "TemporaryObjects"
  )
  $observedKeys = @($Counts.PSObject.Properties.Name)
  if ($Counts -is [System.Collections.IDictionary]) { $observedKeys = @($Counts.Keys | ForEach-Object { [string]$_ }) }
  Assert-Condition -Condition ((@($observedKeys | Sort-Object) -join "|") -ceq (@($expectedKeys | Sort-Object) -join "|")) -Code "manifest_diagnostic_count_shape_rejected"
  foreach ($key in $expectedKeys) {
    $value = if ($Counts -is [System.Collections.IDictionary]) { $Counts[$key] } else { $Counts.$key }
    Assert-Condition -Condition (Test-NonnegativeInteger -Value $value) -Code ("manifest_diagnostic_count_type_rejected_" + $key.ToLowerInvariant())
  }
}

function Assert-ExpectedActivityFixtureShape {
  param([AllowNull()][object]$Fixture)
  if ($null -eq $Fixture) { return }
  $keys = @($Fixture.PSObject.Properties.Name)
  if ($Fixture -is [System.Collections.IDictionary]) { $keys = @($Fixture.Keys | ForEach-Object { [string]$_ }) }
  Assert-Condition -Condition ((@($keys | Sort-Object) -join "|") -ceq "Id|RowFingerprint") -Code "manifest_activity_fixture_shape_rejected"
  Assert-Condition -Condition ([string]$Fixture.Id -cmatch '^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$') -Code "manifest_activity_fixture_id_rejected"
  Assert-Condition -Condition ([string]$Fixture.RowFingerprint -cmatch '^[0-9a-f]{32}$') -Code "manifest_activity_fixture_fingerprint_rejected"
}

function Assert-FingerprintRecordShape {
  param(
    [Parameter(Mandatory = $true)][object]$Fingerprint,
    [Parameter(Mandatory = $true)][string]$CodePrefix
  )
  foreach ($field in @(
    "State", "PeriodHash", "AuthorityHash", "AssignmentHash", "ResolverHash", "BoundaryContractHash",
    "Ms20CandidateCount", "Ms20CandidateSetHash",
    "FunctionInventoryCount", "FunctionInventoryHash", "ExpectedTriggerMatchCount", "TriggerInventoryHash",
    "ConstraintInventoryHash", "AuditConstraintCount", "IndexInventoryHash", "TableSecurityHash",
    "RoutineAclHash", "NonexistentHelperCount", "CalendarLockHelperCount", "CompleteTriggerInventoryValid",
    "ActivitiesConstraintInventoryValid", "PeriodConstraintInventoryValid", "CompleteAuditConstraintInventoryValid",
    "CompleteIndexInventoryValid", "TableAclContractValid", "RlsContractValid", "PolicyContractValid"
  )) {
    Assert-Condition -Condition (Test-ObjectProperty -Value $Fingerprint -Name $field) -Code ($CodePrefix + "_field_missing_" + $field.ToLowerInvariant())
  }
}

function Test-ObjectProperty {
  param(
    [Parameter(Mandatory = $true)][object]$Value,
    [Parameter(Mandatory = $true)][string]$Name
  )
  if ($Value -is [System.Collections.IDictionary]) { return $Value.Contains($Name) }
  return $Value.PSObject.Properties.Name -contains $Name
}

function Get-ObjectPropertyNames {
  param([Parameter(Mandatory = $true)][object]$Value)
  if ($Value -is [System.Collections.IDictionary]) { return @($Value.Keys | ForEach-Object { [string]$_ }) }
  return @($Value.PSObject.Properties.Name)
}

function Assert-ManifestRecord {
  param(
    [Parameter(Mandatory = $true)][object]$Manifest,
    [AllowNull()][string]$ExpectedRunId,
    [bool]$HasRejectedEvidence = $false,
    [bool]$HasApprovedEvidence = $false,
    [bool]$HasFinalPostcheckEvidence = $false,
    [bool]$HasFailurePostcheckEvidence = $false,
    [bool]$FinalPostcheckMarkerValid = $false,
    [bool]$FailurePostcheckMarkerValid = $false,
    [ValidateRange(0, 4)][int]$TotalPublishingArtifacts = 0,
    [AllowNull()][string]$RejectedEvidenceHash,
    [AllowNull()][string]$ApprovedEvidenceHash,
    [AllowNull()][string]$FinalPostcheckEvidenceHash
  )
  foreach ($property in @(
    "HarnessVersion", "RunId", "SourceHead", "TargetClass", "RunStatus", "CompletedPhase",
    "ActivePhase", "ActiveScenario", "AttemptNumber", "MigrationSha256", "RollbackSha256",
    "HarnessSha256", "ApprovedScenarios", "ApprovedScenarioResults", "ExpectedDatabaseState",
    "BaselineFingerprint", "Post0011Fingerprint", "ExpectedDiagnosticCounts",
    "ExpectedActivityFixture", "InstallationFixtureId", "ActiveWorkerPids", "FailureCode", "EvidenceHashes"
  )) {
    Assert-Condition -Condition (Test-ObjectProperty -Value $Manifest -Name $property) -Code ("manifest_property_missing_" + $property.ToLowerInvariant())
  }
  Assert-Condition -Condition ($Manifest.HarnessVersion -ceq $script:HarnessVersion) -Code "resume_harness_version_rejected"
  Assert-Condition -Condition ([string]$Manifest.RunId -cmatch '^[0-9]{8}T[0-9]{6}Z-[a-f0-9]{8}$') -Code "manifest_run_id_rejected"
  if (-not [string]::IsNullOrWhiteSpace($ExpectedRunId)) {
    Assert-Condition -Condition ([string]$Manifest.RunId -ceq $ExpectedRunId) -Code "manifest_run_id_path_mismatch"
  }
  Assert-Condition -Condition ([string]$Manifest.SourceHead -cmatch '^[0-9a-f]{40}$') -Code "manifest_source_head_rejected"
  foreach ($hashField in @("MigrationSha256", "RollbackSha256", "HarnessSha256")) {
    Assert-Condition -Condition (Test-LowercaseSha256 -Value $Manifest.$hashField) -Code ("manifest_sha256_rejected_" + $hashField.ToLowerInvariant())
  }
  Assert-Condition -Condition ($Manifest.TargetClass -ceq "DISPOSABLE_LAB") -Code "resume_target_class_rejected"
  Assert-Condition -Condition ($script:RunStatuses -ccontains [string]$Manifest.RunStatus) -Code "resume_run_status_rejected"
  Assert-Condition -Condition (Test-NonnegativeInteger -Value $Manifest.AttemptNumber) -Code "resume_attempt_number_rejected"
  Assert-Condition -Condition ($Manifest.ApprovedScenarios -is [System.Array]) -Code "manifest_approved_scenarios_shape_rejected"
  Assert-Condition -Condition ($Manifest.ApprovedScenarioResults -is [System.Array]) -Code "manifest_approved_results_shape_rejected"
  Assert-Condition -Condition ($Manifest.ActiveWorkerPids -is [System.Array]) -Code "manifest_active_worker_pids_shape_rejected"
  foreach ($pidValue in @($Manifest.ActiveWorkerPids)) {
    Assert-Condition -Condition (Test-PositiveInteger -Value $pidValue) -Code "manifest_active_worker_pid_rejected"
  }
  Assert-Condition -Condition (@($Manifest.ActiveWorkerPids).Count -eq @($Manifest.ActiveWorkerPids | Sort-Object -Unique).Count) -Code "manifest_active_worker_pid_duplicate_rejected"

  $completedPhase = [string]$Manifest.CompletedPhase
  Assert-Condition -Condition (-not [string]::IsNullOrWhiteSpace($completedPhase)) -Code "resume_phase_rejected"
  $completedIndex = Get-PhaseIndex -Phase $completedPhase
  Assert-Condition -Condition ($completedPhase -ceq "NONE" -or $completedIndex -ge 0) -Code "resume_phase_rejected"
  Assert-Condition -Condition ([string]$Manifest.ExpectedDatabaseState -ceq (Get-ExpectedStateForCompletedPhase -Phase $completedPhase)) -Code "resume_expected_database_state_rejected"
  $activePhase = if ($null -eq $Manifest.ActivePhase) { $null } else { [string]$Manifest.ActivePhase }
  $activeScenario = if ($null -eq $Manifest.ActiveScenario) { $null } else { [string]$Manifest.ActiveScenario }
  if ($null -ne $activePhase) {
    Assert-Condition -Condition (-not [string]::IsNullOrWhiteSpace($activePhase)) -Code "resume_active_phase_rejected"
    $activeIndex = Get-PhaseIndex -Phase $activePhase
    Assert-Condition -Condition ($activeIndex -ge 0 -and $activeIndex -eq (Get-NextRemotePhaseIndex -CompletedPhase $completedPhase)) -Code "resume_active_phase_rejected"
  }
  else {
    $activeIndex = -1
  }
  if ($null -ne $activeScenario) {
    Assert-Condition -Condition (-not [string]::IsNullOrWhiteSpace($activeScenario)) -Code "resume_active_scenario_rejected"
    Assert-Condition -Condition ($activeScenario -in @($script:RequiredScenarios | ForEach-Object { $_.Id })) -Code "resume_active_scenario_rejected"
    $activeScenarioDefinition = $script:RequiredScenarios | Where-Object { $_.Id -ceq $activeScenario } | Select-Object -First 1
    Assert-Condition -Condition ($null -ne $activePhase -and $activeScenarioDefinition.Phase -ceq $activePhase) -Code "resume_active_scenario_phase_rejected"
  }

  if ($completedIndex -ge 1) {
    Assert-Condition -Condition ($null -ne $Manifest.BaselineFingerprint) -Code "resume_baseline_fingerprint_missing"
    Assert-FingerprintRecordShape -Fingerprint $Manifest.BaselineFingerprint -CodePrefix "resume_baseline_fingerprint"
  }
  if ($completedIndex -ge 2) {
    Assert-Condition -Condition ($null -ne $Manifest.Post0011Fingerprint) -Code "resume_post0011_fingerprint_missing"
    Assert-FingerprintRecordShape -Fingerprint $Manifest.Post0011Fingerprint -CodePrefix "resume_post0011_fingerprint"
  }

  Assert-Condition -Condition (-not (($HasRejectedEvidence -or $HasFailurePostcheckEvidence) -and ($HasApprovedEvidence -or $HasFinalPostcheckEvidence))) -Code "run_evidence_conflict_rejected"
  Assert-Condition -Condition (-not (($HasRejectedEvidence -or $HasFailurePostcheckEvidence) -and [string]$Manifest.RunStatus -ne "rejected")) -Code "rejection_finalization_incomplete"
  Assert-Condition -Condition (-not (($HasApprovedEvidence -or $HasFinalPostcheckEvidence) -and [string]$Manifest.RunStatus -ne "approved")) -Code "approval_finalization_incomplete"
  if ([string]$Manifest.RunStatus -ceq "approved") {
    Assert-Condition -Condition (-not ($HasApprovedEvidence -xor $HasFinalPostcheckEvidence)) -Code "final_evidence_pair_incomplete"
  }
  $savedResults = @($Manifest.ApprovedScenarioResults)
  $savedIds = @($savedResults | ForEach-Object { [string]$_.Id })
  $approvedIds = @($Manifest.ApprovedScenarios | ForEach-Object { [string]$_ })
  Assert-Condition -Condition ($savedIds.Count -eq @($savedIds | Sort-Object -Unique).Count) -Code "resume_scenario_duplicate_rejected"
  Assert-Condition -Condition ($approvedIds.Count -eq @($approvedIds | Sort-Object -Unique).Count) -Code "resume_approved_id_duplicate_rejected"
  Assert-Condition -Condition ((@($savedIds | Sort-Object) -join "|") -ceq (@($approvedIds | Sort-Object) -join "|")) -Code "resume_scenario_set_mismatch"

  foreach ($result in $savedResults) {
    Assert-Condition -Condition ($null -ne $result) -Code "resume_scenario_result_null_rejected"
    foreach ($field in @("Id", "Outcome", "Assertions", "CompletedAtUtc")) {
      Assert-Condition -Condition (Test-ObjectProperty -Value $result -Name $field) -Code ("resume_scenario_field_missing_" + $field.ToLowerInvariant())
    }
    $definition = $script:RequiredScenarios | Where-Object { $_.Id -ceq [string]$result.Id } | Select-Object -First 1
    Assert-Condition -Condition ($null -ne $definition) -Code "resume_scenario_unknown"
    Assert-Condition -Condition (-not [string]::IsNullOrWhiteSpace([string]$result.Outcome)) -Code "resume_scenario_outcome_rejected"
    $completedAt = [DateTimeOffset]::MinValue
    $validTimestamp = [DateTimeOffset]::TryParse([string]$result.CompletedAtUtc, [ref]$completedAt)
    Assert-Condition -Condition ($validTimestamp -and $completedAt.Offset -eq [TimeSpan]::Zero) -Code "resume_scenario_timestamp_rejected"
    Assert-Condition -Condition ($null -ne $result.Assertions) -Code "resume_scenario_assertions_missing"
    $assertions = @(Get-AssertionProperties -Assertions $result.Assertions)
    Assert-Condition -Condition ($assertions.Count -gt 0) -Code "resume_scenario_assertions_missing"
    foreach ($assertion in $assertions) {
      Assert-Condition -Condition ($assertion.Value -is [bool] -and $assertion.Value -eq $true) -Code "resume_scenario_assertion_rejected"
    }
    $resultPhaseIndex = Get-PhaseIndex -Phase ([string]$definition.Phase)
    Assert-Condition -Condition ($resultPhaseIndex -le $completedIndex -or ($null -ne $activePhase -and $definition.Phase -ceq $activePhase)) -Code "resume_later_inactive_result_rejected"
  }

  $expectedCompletedIds = @(Get-ScenarioIdsThroughPhase -Phase $completedPhase)
  Assert-Condition -Condition ((@($savedIds | Where-Object { $_ -in $expectedCompletedIds } | Sort-Object) -join "|") -ceq (@($expectedCompletedIds | Sort-Object) -join "|")) -Code "resume_completed_phase_result_missing"

  if ($null -ne $activePhase) {
    $activeIds = @(Get-ScenarioIdsForPhase -Phase $activePhase)
    $observedActiveIds = @($savedIds | Where-Object { $_ -in $activeIds })
    $firstMissing = $activeIds | Where-Object { $_ -notin $observedActiveIds } | Select-Object -First 1
    if ($null -eq $firstMissing) {
      Assert-Condition -Condition ($null -eq $activeScenario) -Code "resume_active_scenario_should_be_clear"
    }
    else {
      Assert-Condition -Condition ($activeScenario -ceq $firstMissing) -Code "resume_active_scenario_not_next"
    }
  }

  if ($null -ne $Manifest.ExpectedDiagnosticCounts) {
    Assert-ExpectedDiagnosticCountsShape -Counts $Manifest.ExpectedDiagnosticCounts
  }
  if ($completedPhase -ceq "NONE") {
    Assert-Condition -Condition ($null -eq $Manifest.ExpectedDiagnosticCounts) -Code "resume_uncompleted_boundary_counts_rejected"
  }
  else {
    Assert-Condition -Condition ($null -ne $Manifest.ExpectedDiagnosticCounts) -Code "resume_boundary_diagnostic_counts_missing"
    $expectedCounts = Get-ExpectedDiagnosticCountsForPhase -Phase $completedPhase
    foreach ($key in @(
      "FixturePeriods", "Activities", "AuditEvents", "OpenWorkers", "GrantedSem01AdvisoryLocks",
      "WaitingSem01AdvisoryLocks", "TotalSem01AdvisoryLocks", "TransientWorkerSqlFiles", "TemporaryObjects"
    )) {
      Assert-Condition -Condition ($Manifest.ExpectedDiagnosticCounts.$key -eq $expectedCounts.$key) -Code ("resume_boundary_count_rejected_" + $key.ToLowerInvariant())
    }
  }
  Assert-ExpectedActivityFixtureShape -Fixture $Manifest.ExpectedActivityFixture
  $fixtureExpected = $completedPhase -ceq "PHASE_02_INSTALLATION_MATRIX"
  if ($fixtureExpected) {
    Assert-Condition -Condition ($null -ne $Manifest.ExpectedActivityFixture) -Code "manifest_phase02_activity_fixture_missing"
    Assert-Condition -Condition ([string]$Manifest.InstallationFixtureId -ceq [string]$Manifest.ExpectedActivityFixture.Id) -Code "manifest_phase02_activity_fixture_id_mismatch"
  }
  elseif ($completedIndex -ge 3) {
    Assert-Condition -Condition ($null -eq $Manifest.ExpectedActivityFixture -and $null -eq $Manifest.InstallationFixtureId) -Code "manifest_post_phase02_activity_fixture_retained"
  }

  $runStatus = [string]$Manifest.RunStatus
  if ($runStatus -ceq "ready") {
    Assert-Condition -Condition ($null -eq $activePhase -and $null -eq $activeScenario) -Code "resume_ready_active_state_rejected"
    Assert-Condition -Condition ($null -eq $Manifest.FailureCode -and $null -eq $Manifest.EvidenceHashes) -Code "ready_terminal_state_rejected"
    Assert-Condition -Condition (-not $HasRejectedEvidence -and -not $HasApprovedEvidence -and -not $HasFinalPostcheckEvidence -and -not $HasFailurePostcheckEvidence) -Code "ready_evidence_rejected"
    Assert-Condition -Condition (@($Manifest.ActiveWorkerPids).Count -eq 0) -Code "ready_active_worker_pids_rejected"
    Assert-Condition -Condition ($completedPhase -ceq "NONE" -or ($completedIndex -ge 1 -and $completedIndex -le 5)) -Code "ready_completed_phase_rejected"
    if ($completedPhase -ceq "NONE") {
      Assert-Condition -Condition ([int]$Manifest.AttemptNumber -eq 0 -and $savedIds.Count -eq 0 -and $approvedIds.Count -eq 0) -Code "ready_fresh_history_rejected"
      Assert-Condition -Condition ($null -eq $Manifest.BaselineFingerprint -and $null -eq $Manifest.Post0011Fingerprint -and $null -eq $Manifest.ExpectedDiagnosticCounts -and $null -eq $Manifest.ExpectedActivityFixture -and $null -eq $Manifest.InstallationFixtureId) -Code "ready_fresh_boundary_state_rejected"
    }
  }

  if ($runStatus -ceq "running") {
    Assert-Condition -Condition ($null -ne $activePhase) -Code "resume_running_phase_missing"
    Assert-Condition -Condition ($null -eq $Manifest.FailureCode -and $null -eq $Manifest.EvidenceHashes) -Code "running_terminal_state_rejected"
    Assert-Condition -Condition (-not $HasRejectedEvidence -and -not $HasApprovedEvidence -and -not $HasFinalPostcheckEvidence -and -not $HasFailurePostcheckEvidence) -Code "running_evidence_rejected"
  }

  if ($runStatus -ceq "rejected") {
    Assert-Condition -Condition (@($Manifest.ActiveWorkerPids).Count -eq 0) -Code "rejected_active_worker_pids_rejected"
    Assert-Condition -Condition ($HasRejectedEvidence -and -not $HasApprovedEvidence -and -not $HasFinalPostcheckEvidence) -Code "rejected_evidence_missing"
    Assert-Condition -Condition (-not $HasFailurePostcheckEvidence -or $FailurePostcheckMarkerValid) -Code "rejected_failure_postcheck_marker_rejected"
    Assert-Condition -Condition ($TotalPublishingArtifacts -eq 0) -Code "rejected_publishing_artifact_rejected"
    Assert-Condition -Condition ([string]$Manifest.FailureCode -cmatch '^[a-z0-9]+(?:_[a-z0-9]+)*(?:_(?:40P01|55P03|25000|23514|42501))?$') -Code "rejected_failure_code_rejected"
    $rejectedHashKeys = if ($null -eq $Manifest.EvidenceHashes) { @() } else { @(Get-ObjectPropertyNames -Value $Manifest.EvidenceHashes) }
    Assert-Condition -Condition (($rejectedHashKeys -join "|") -ceq "Rejected") -Code "rejected_evidence_hash_shape_rejected"
    Assert-Condition -Condition (Test-LowercaseSha256 -Value $Manifest.EvidenceHashes.Rejected) -Code "rejected_evidence_hash_rejected"
    Assert-Condition -Condition ([string]$Manifest.EvidenceHashes.Rejected -ceq $RejectedEvidenceHash) -Code "rejected_evidence_actual_hash_mismatch"
  }

  if ($runStatus -ceq "approved") {
    Assert-Condition -Condition ($completedPhase -ceq "PHASE_06_FINAL_POSTCHECK" -and $null -eq $activePhase -and $null -eq $activeScenario) -Code "resume_approved_state_rejected"
    Assert-Condition -Condition (@($Manifest.ActiveWorkerPids).Count -eq 0) -Code "approved_active_worker_pids_rejected"
    Assert-Condition -Condition ($HasApprovedEvidence -and $HasFinalPostcheckEvidence -and $FinalPostcheckMarkerValid -and -not $HasRejectedEvidence -and -not $HasFailurePostcheckEvidence) -Code "approved_evidence_missing"
    Assert-Condition -Condition ($TotalPublishingArtifacts -eq 0) -Code "approved_publishing_artifact_rejected"
    Assert-Condition -Condition ($null -eq $Manifest.FailureCode) -Code "approved_failure_code_rejected"
    $approvedHashKeys = if ($null -eq $Manifest.EvidenceHashes) { @() } else { @(Get-ObjectPropertyNames -Value $Manifest.EvidenceHashes) }
    Assert-Condition -Condition ((@($approvedHashKeys | Sort-Object) -join "|") -ceq "Approved|Postcheck") -Code "approved_evidence_hash_shape_rejected"
    Assert-Condition -Condition (Test-LowercaseSha256 -Value $Manifest.EvidenceHashes.Approved) -Code "approved_evidence_hash_rejected"
    Assert-Condition -Condition (Test-LowercaseSha256 -Value $Manifest.EvidenceHashes.Postcheck) -Code "approved_postcheck_hash_rejected"
    Assert-Condition -Condition ([string]$Manifest.EvidenceHashes.Approved -ceq $ApprovedEvidenceHash -and [string]$Manifest.EvidenceHashes.Postcheck -ceq $FinalPostcheckEvidenceHash) -Code "approved_evidence_actual_hash_mismatch"
  }

  if ($runStatus -ceq "approved") {
    $allIds = @($script:RequiredScenarios | Sort-Object Ordinal | ForEach-Object { $_.Id })
    Assert-Condition -Condition ($savedIds.Count -eq 24 -and ((@($savedIds | Sort-Object) -join "|") -ceq (@($allIds | Sort-Object) -join "|"))) -Code "approved_scenario_contract_rejected"
  }
  return $Manifest
}

function Read-Manifest {
  param([Parameter(Mandatory = $true)][object]$Paths)
  Assert-Condition -Condition (Test-Path -LiteralPath $Paths.Manifest -PathType Leaf) -Code "resume_manifest_missing"
  $manifest = Get-Content -LiteralPath $Paths.Manifest -Raw -Encoding utf8 | ConvertFrom-Json
  $expectedRunId = [System.IO.Path]::GetFileName([System.IO.Path]::GetFullPath($Paths.Root).TrimEnd('\'))
  $artifacts = Get-TerminalArtifactInventory -Paths $Paths
  return Assert-ManifestRecord -Manifest $manifest -ExpectedRunId $expectedRunId `
    -HasRejectedEvidence $artifacts.RejectedEvidenceExists -HasApprovedEvidence $artifacts.ApprovedEvidenceExists `
    -HasFinalPostcheckEvidence $artifacts.ApprovedPostcheckExists -HasFailurePostcheckEvidence $artifacts.FailurePostcheckExists `
    -FinalPostcheckMarkerValid $artifacts.ApprovedPostcheckMarkerValid -FailurePostcheckMarkerValid $artifacts.FailurePostcheckMarkerValid `
    -TotalPublishingArtifacts $artifacts.TotalPublishingArtifacts `
    -RejectedEvidenceHash $(if ($artifacts.RejectedEvidenceExists) { Get-Sha256 -Path $Paths.Failure } else { $null }) `
    -ApprovedEvidenceHash $(if ($artifacts.ApprovedEvidenceExists) { Get-Sha256 -Path $Paths.Evidence } else { $null }) `
    -FinalPostcheckEvidenceHash $(if ($artifacts.ApprovedPostcheckExists) { Get-Sha256 -Path $Paths.FinalPostcheck } else { $null })
}

function Read-ManifestForDiagnostic {
  param([Parameter(Mandatory = $true)][object]$Paths)
  Assert-Condition -Condition (Test-Path -LiteralPath $Paths.Manifest -PathType Leaf) -Code "resume_manifest_missing"
  $manifest = Get-Content -LiteralPath $Paths.Manifest -Raw -Encoding utf8 | ConvertFrom-Json
  $expectedRunId = [System.IO.Path]::GetFileName([System.IO.Path]::GetFullPath($Paths.Root).TrimEnd('\'))
  $artifacts = Get-TerminalArtifactInventory -Paths $Paths
  $classification = Get-TerminalArtifactClassification -Inventory $artifacts -RunStatus ([string]$manifest.RunStatus)
  if ($classification.EvidenceContractMatches -and [string]$manifest.RunStatus -ceq "approved") {
    return Assert-ManifestRecord -Manifest $manifest -ExpectedRunId $expectedRunId -HasApprovedEvidence $artifacts.ApprovedEvidenceExists -HasFinalPostcheckEvidence $artifacts.ApprovedPostcheckExists `
      -HasFailurePostcheckEvidence $artifacts.FailurePostcheckExists -FinalPostcheckMarkerValid $artifacts.ApprovedPostcheckMarkerValid `
      -FailurePostcheckMarkerValid $artifacts.FailurePostcheckMarkerValid -TotalPublishingArtifacts $artifacts.TotalPublishingArtifacts `
      -ApprovedEvidenceHash $(if ($artifacts.ApprovedEvidenceExists) { Get-Sha256 -Path $Paths.Evidence } else { $null }) `
      -FinalPostcheckEvidenceHash $(if ($artifacts.ApprovedPostcheckExists) { Get-Sha256 -Path $Paths.FinalPostcheck } else { $null })
  }
  if ($classification.EvidenceContractMatches -and [string]$manifest.RunStatus -ceq "rejected") {
    return Assert-ManifestRecord -Manifest $manifest -ExpectedRunId $expectedRunId -HasRejectedEvidence $artifacts.RejectedEvidenceExists `
      -HasApprovedEvidence $artifacts.ApprovedEvidenceExists -HasFinalPostcheckEvidence $artifacts.ApprovedPostcheckExists `
      -HasFailurePostcheckEvidence $artifacts.FailurePostcheckExists -FinalPostcheckMarkerValid $artifacts.ApprovedPostcheckMarkerValid `
      -FailurePostcheckMarkerValid $artifacts.FailurePostcheckMarkerValid -TotalPublishingArtifacts $artifacts.TotalPublishingArtifacts `
      -RejectedEvidenceHash $(if ($artifacts.RejectedEvidenceExists) { Get-Sha256 -Path $Paths.Failure } else { $null })
  }
  foreach ($property in @(
    "HarnessVersion", "RunId", "SourceHead", "MigrationSha256", "RollbackSha256", "HarnessSha256", "RunStatus",
    "CompletedPhase", "ActivePhase", "ActiveScenario", "ExpectedDatabaseState", "BaselineFingerprint", "Post0011Fingerprint",
    "ExpectedDiagnosticCounts", "ExpectedActivityFixture", "ActiveWorkerPids"
  )) { Assert-Condition -Condition (Test-ObjectProperty -Value $manifest -Name $property) -Code ("manifest_property_missing_" + $property.ToLowerInvariant()) }
  Assert-Condition -Condition ([string]$manifest.RunId -ceq $expectedRunId) -Code "manifest_run_id_path_mismatch"
  Assert-Condition -Condition ([string]$manifest.RunStatus -in $script:RunStatuses) -Code "manifest_run_status_rejected"
  return $manifest
}

function New-Manifest {
  param([Parameter(Mandatory = $true)][string]$Identifier)
  return [ordered]@{
    HarnessVersion = $script:HarnessVersion
    RunId = $Identifier
    SourceHead = Get-SourceHead
    MigrationSha256 = $script:ExpectedHashes["supabase/migrations/0011_academic_period_administration.sql"]
    RollbackSha256 = $script:ExpectedHashes["supabase/reconciliation/0011_academic_period_administration_rollback.sql"]
    HarnessSha256 = Get-Sha256 -Path $PSCommandPath
    TargetClass = "DISPOSABLE_LAB"
    RunStatus = "ready"
    CompletedPhase = "NONE"
    ActivePhase = $null
    ActiveScenario = $null
    AttemptNumber = 0
    ExpectedDatabaseState = "POST0010"
    ApprovedScenarios = @()
    ApprovedScenarioResults = @()
    FailureCode = $null
    EvidenceHashes = $null
    ActiveWorkerPids = @()
    InstallationFixtureId = $null
    BaselineFingerprint = $null
    Post0011Fingerprint = $null
    ExpectedDiagnosticCounts = $null
    ExpectedActivityFixture = $null
  }
}

function New-LocalManifestFixture {
  param(
    [Parameter(Mandatory = $true)][string]$CompletedPhase,
    [Parameter(Mandatory = $true)][string]$RunStatus,
    [AllowNull()][object]$ActivePhase,
    [AllowNull()][object]$ActiveScenario,
    [string[]]$ResultIds = @()
  )
  $fixture = New-Manifest -Identifier "20260812T000000Z-00000000"
  $fixture.CompletedPhase = $CompletedPhase
  $fixture.RunStatus = $RunStatus
  $fixture.ActivePhase = $ActivePhase
  $fixture.ActiveScenario = $ActiveScenario
  $fixture.AttemptNumber = if ($CompletedPhase -ceq "NONE" -and $null -eq $ActivePhase) { 0 } else { 1 }
  $fixture.ExpectedDatabaseState = Get-ExpectedStateForCompletedPhase -Phase $CompletedPhase
  $fixture.ExpectedDiagnosticCounts = if ($CompletedPhase -cne "NONE") { Get-ExpectedDiagnosticCountsForPhase -Phase $CompletedPhase } else { $null }
  if ($CompletedPhase -ceq "PHASE_02_INSTALLATION_MATRIX") {
    $fixtureId = "00000000" + "-0000-4000-8000-" + "000000000000"
    $fixture.InstallationFixtureId = $fixtureId
    $fixture.ExpectedActivityFixture = [ordered]@{ Id = $fixtureId; RowFingerprint = ("a" * 32) }
  }
  $fingerprintFixture = [ordered]@{
    State = $fixture.ExpectedDatabaseState
    PeriodHash = "period"
    AuthorityHash = "authority"
    AssignmentHash = "assignment"
    Ms20CandidateCount = 2
    Ms20CandidateSetHash = ("a" * 32)
    ResolverHash = "resolver"
    BoundaryContractHash = "boundary"
    FunctionInventoryCount = 18
    FunctionInventoryHash = "functions"
    ExpectedTriggerMatchCount = if ($fixture.ExpectedDatabaseState -ceq "POST0011") { 10 } else { 3 }
    TriggerInventoryHash = "triggers"
    ConstraintInventoryHash = "constraints"
    AuditConstraintCount = 7
    IndexInventoryHash = "indexes"
    TableSecurityHash = "table_security"
    RoutineAclHash = "routine_acl"
    NonexistentHelperCount = 0
    CalendarLockHelperCount = 1
    CompleteTriggerInventoryValid = $true
    ActivitiesConstraintInventoryValid = $true
    PeriodConstraintInventoryValid = $true
    CompleteAuditConstraintInventoryValid = $true
    CompleteIndexInventoryValid = $true
    TableAclContractValid = $true
    RlsContractValid = $true
    PolicyContractValid = $true
  }
  if ((Get-PhaseIndex -Phase $CompletedPhase) -ge 1) { $fixture.BaselineFingerprint = $fingerprintFixture }
  if ((Get-PhaseIndex -Phase $CompletedPhase) -ge 2) { $fixture.Post0011Fingerprint = $fingerprintFixture }
  $fixture.ApprovedScenarios = @($ResultIds)
  $fixture.ApprovedScenarioResults = @($ResultIds | ForEach-Object {
    [pscustomobject]@{
      Id = $_
      Outcome = "local_manifest_fixture"
      Assertions = [pscustomobject]@{ FixtureAssertion = $true }
      CompletedAtUtc = "2026-08-12T00:00:00.0000000+00:00"
    }
  })
  if ($RunStatus -ceq "rejected") {
    $fixture.FailureCode = "local_fixture_rejected"
    $fixture.EvidenceHashes = [ordered]@{ Rejected = ("b" * 64) }
  }
  elseif ($RunStatus -ceq "approved") {
    $fixture.EvidenceHashes = [ordered]@{ Approved = ("c" * 64); Postcheck = ("d" * 64) }
  }
  return $fixture
}

function Assert-LocalStableFailure {
  param(
    [Parameter(Mandatory = $true)][scriptblock]$Operation,
    [Parameter(Mandatory = $true)][string]$ExpectedCode
  )
  $observed = $null
  try { & $Operation }
  catch { $observed = $_.Exception.Message }
  Assert-Condition -Condition ($observed -ceq $ExpectedCode) -Code ("local_negative_fixture_failed_" + $ExpectedCode)
}

function Assert-ManifestContractFixtures {
  Assert-Condition -Condition ((Get-NextRemotePhaseIndex -CompletedPhase "NONE") -eq (Get-PhaseIndex -Phase "PHASE_01_READ_ONLY_BASELINE")) -Code "local_none_next_phase_fixture_rejected"
  $phase02Ids = @($script:RequiredScenarios | Where-Object { $_.Phase -ceq "PHASE_02_INSTALLATION_MATRIX" } | Sort-Object Ordinal | ForEach-Object { $_.Id })
  $throughPhase04 = @($script:RequiredScenarios | Where-Object { (Get-PhaseIndex -Phase $_.Phase) -le (Get-PhaseIndex -Phase "PHASE_04_REAPPLY_0011") } | Sort-Object Ordinal | ForEach-Object { $_.Id })
  $ms07Through10 = @($script:RequiredScenarios | Where-Object { $_.Ordinal -ge 7 -and $_.Ordinal -le 10 } | Sort-Object Ordinal | ForEach-Object { $_.Id })

  [void](Assert-ManifestRecord -Manifest (New-LocalManifestFixture -CompletedPhase "NONE" -RunStatus "ready" -ActivePhase $null -ActiveScenario $null))
  [void](Assert-ManifestRecord -Manifest (New-LocalManifestFixture -CompletedPhase "PHASE_01_READ_ONLY_BASELINE" -RunStatus "ready" -ActivePhase $null -ActiveScenario $null))
  [void](Assert-ManifestRecord -Manifest (New-LocalManifestFixture -CompletedPhase "PHASE_02_INSTALLATION_MATRIX" -RunStatus "ready" -ActivePhase $null -ActiveScenario $null -ResultIds $phase02Ids))
  [void](Assert-ManifestRecord -Manifest (New-LocalManifestFixture -CompletedPhase "PHASE_03_ROLLBACK_MATRIX" -RunStatus "ready" -ActivePhase $null -ActiveScenario $null -ResultIds (Get-ScenarioIdsThroughPhase -Phase "PHASE_03_ROLLBACK_MATRIX")))
  [void](Assert-ManifestRecord -Manifest (New-LocalManifestFixture -CompletedPhase "PHASE_04_REAPPLY_0011" -RunStatus "ready" -ActivePhase $null -ActiveScenario $null -ResultIds (Get-ScenarioIdsThroughPhase -Phase "PHASE_04_REAPPLY_0011")))
  [void](Assert-ManifestRecord -Manifest (New-LocalManifestFixture -CompletedPhase "PHASE_05_RUNTIME_MATRIX" -RunStatus "ready" -ActivePhase $null -ActiveScenario $null -ResultIds (Get-ScenarioIdsThroughPhase -Phase "PHASE_05_RUNTIME_MATRIX")))
  [void](Assert-ManifestRecord -Manifest (New-LocalManifestFixture -CompletedPhase "PHASE_01_READ_ONLY_BASELINE" -RunStatus "running" -ActivePhase "PHASE_02_INSTALLATION_MATRIX" -ActiveScenario $phase02Ids[1] -ResultIds @($phase02Ids[0])))
  [void](Assert-ManifestRecord -Manifest (New-LocalManifestFixture -CompletedPhase "PHASE_04_REAPPLY_0011" -RunStatus "running" -ActivePhase "PHASE_05_RUNTIME_MATRIX" -ActiveScenario "MS11_OVERLAPPING_CREATIONS" -ResultIds @($throughPhase04 + $ms07Through10)))

  $duplicate = New-LocalManifestFixture -CompletedPhase "PHASE_02_INSTALLATION_MATRIX" -RunStatus "ready" -ActivePhase $null -ActiveScenario $null -ResultIds @($phase02Ids + $phase02Ids[0])
  Assert-LocalStableFailure -ExpectedCode "resume_scenario_duplicate_rejected" -Operation { [void](Assert-ManifestRecord -Manifest $duplicate) }

  $later = New-LocalManifestFixture -CompletedPhase "PHASE_01_READ_ONLY_BASELINE" -RunStatus "running" -ActivePhase "PHASE_02_INSTALLATION_MATRIX" -ActiveScenario $phase02Ids[0] -ResultIds @("MS07_ADMIN_RPC_REJECTS_HIGH_ISOLATION")
  Assert-LocalStableFailure -ExpectedCode "resume_later_inactive_result_rejected" -Operation { [void](Assert-ManifestRecord -Manifest $later) }

  $rejected = New-LocalManifestFixture -CompletedPhase "PHASE_01_READ_ONLY_BASELINE" -RunStatus "rejected" -ActivePhase $null -ActiveScenario $null
  [void](Assert-ManifestRecord -Manifest $rejected -HasRejectedEvidence $true -RejectedEvidenceHash ("b" * 64))
  Assert-LocalStableFailure -ExpectedCode "resume_rejected_run_rejected" -Operation { Assert-ManifestExecuteEligibility -Manifest $rejected -HasRejectedEvidence $true }

  $approvedIds = @($script:RequiredScenarios | Sort-Object Ordinal | ForEach-Object { $_.Id })
  $approved = New-LocalManifestFixture -CompletedPhase "PHASE_06_FINAL_POSTCHECK" -RunStatus "approved" -ActivePhase $null -ActiveScenario $null -ResultIds $approvedIds
  [void](Assert-ManifestRecord -Manifest $approved -HasApprovedEvidence $true -HasFinalPostcheckEvidence $true -FinalPostcheckMarkerValid $true -ApprovedEvidenceHash ("c" * 64) -FinalPostcheckEvidenceHash ("d" * 64))
  $readyPhase06 = New-LocalManifestFixture -CompletedPhase "PHASE_06_FINAL_POSTCHECK" -RunStatus "ready" -ActivePhase $null -ActiveScenario $null -ResultIds $approvedIds
  Assert-LocalStableFailure -ExpectedCode "ready_completed_phase_rejected" -Operation { [void](Assert-ManifestRecord -Manifest $readyPhase06) }
  Assert-LocalStableFailure -ExpectedCode "resume_completed_boundary_missing" -Operation { Assert-ManifestExecuteEligibility -Manifest $readyPhase06 }
  $approvedPhase05 = New-LocalManifestFixture -CompletedPhase "PHASE_05_RUNTIME_MATRIX" -RunStatus "approved" -ActivePhase $null -ActiveScenario $null -ResultIds (Get-ScenarioIdsThroughPhase -Phase "PHASE_05_RUNTIME_MATRIX")
  Assert-LocalStableFailure -ExpectedCode "resume_approved_state_rejected" -Operation { [void](Assert-ManifestRecord -Manifest $approvedPhase05 -HasApprovedEvidence $true -HasFinalPostcheckEvidence $true -FinalPostcheckMarkerValid $true -ApprovedEvidenceHash ("c" * 64) -FinalPostcheckEvidenceHash ("d" * 64)) }
  $approvedWithWorker = New-LocalManifestFixture -CompletedPhase "PHASE_06_FINAL_POSTCHECK" -RunStatus "approved" -ActivePhase $null -ActiveScenario $null -ResultIds $approvedIds
  $approvedWithWorker.ActiveWorkerPids = @(101)
  Assert-LocalStableFailure -ExpectedCode "approved_active_worker_pids_rejected" -Operation { [void](Assert-ManifestRecord -Manifest $approvedWithWorker -HasApprovedEvidence $true -HasFinalPostcheckEvidence $true -FinalPostcheckMarkerValid $true -ApprovedEvidenceHash ("c" * 64) -FinalPostcheckEvidenceHash ("d" * 64)) }
  $duplicateWorkers = New-LocalManifestFixture -CompletedPhase "PHASE_01_READ_ONLY_BASELINE" -RunStatus "running" -ActivePhase "PHASE_02_INSTALLATION_MATRIX" -ActiveScenario $phase02Ids[0]
  $duplicateWorkers.ActiveWorkerPids = @(101, 101)
  Assert-LocalStableFailure -ExpectedCode "manifest_active_worker_pid_duplicate_rejected" -Operation { [void](Assert-ManifestRecord -Manifest $duplicateWorkers) }
  $conflicting = New-LocalManifestFixture -CompletedPhase "PHASE_06_FINAL_POSTCHECK" -RunStatus "approved" -ActivePhase $null -ActiveScenario $null -ResultIds $approvedIds
  Assert-LocalStableFailure -ExpectedCode "run_evidence_conflict_rejected" -Operation { [void](Assert-ManifestRecord -Manifest $conflicting -HasRejectedEvidence $true -HasApprovedEvidence $true) }

  $phase02Zero = New-LocalManifestFixture -CompletedPhase "PHASE_02_INSTALLATION_MATRIX" -RunStatus "ready" -ActivePhase $null -ActiveScenario $null -ResultIds $phase02Ids
  $phase02Zero.ExpectedDiagnosticCounts.Activities = 0
  Assert-LocalStableFailure -ExpectedCode "resume_boundary_count_rejected_activities" -Operation { [void](Assert-ManifestRecord -Manifest $phase02Zero) }
  $phase02MissingFixture = New-LocalManifestFixture -CompletedPhase "PHASE_02_INSTALLATION_MATRIX" -RunStatus "ready" -ActivePhase $null -ActiveScenario $null -ResultIds $phase02Ids
  $phase02MissingFixture.ExpectedActivityFixture = $null
  Assert-LocalStableFailure -ExpectedCode "manifest_phase02_activity_fixture_missing" -Operation { [void](Assert-ManifestRecord -Manifest $phase02MissingFixture) }
  $phase02FixtureMismatch = New-LocalManifestFixture -CompletedPhase "PHASE_02_INSTALLATION_MATRIX" -RunStatus "ready" -ActivePhase $null -ActiveScenario $null -ResultIds $phase02Ids
  $phase02FixtureMismatch.InstallationFixtureId = "11111111" + "-1111-4111-8111-" + "111111111111"
  Assert-LocalStableFailure -ExpectedCode "manifest_phase02_activity_fixture_id_mismatch" -Operation { [void](Assert-ManifestRecord -Manifest $phase02FixtureMismatch) }
  $phase03RetainedFixture = New-LocalManifestFixture -CompletedPhase "PHASE_03_ROLLBACK_MATRIX" -RunStatus "ready" -ActivePhase $null -ActiveScenario $null -ResultIds (Get-ScenarioIdsThroughPhase -Phase "PHASE_03_ROLLBACK_MATRIX")
  $phase03RetainedFixture.InstallationFixtureId = "22222222" + "-2222-4222-8222-" + "222222222222"
  Assert-LocalStableFailure -ExpectedCode "manifest_post_phase02_activity_fixture_retained" -Operation { [void](Assert-ManifestRecord -Manifest $phase03RetainedFixture) }
  $missingCount = New-LocalManifestFixture -CompletedPhase "PHASE_01_READ_ONLY_BASELINE" -RunStatus "ready" -ActivePhase $null -ActiveScenario $null
  $missingCount.ExpectedDiagnosticCounts.Remove("Activities")
  Assert-LocalStableFailure -ExpectedCode "manifest_diagnostic_count_shape_rejected" -Operation { [void](Assert-ManifestRecord -Manifest $missingCount) }
  $extraCount = New-LocalManifestFixture -CompletedPhase "PHASE_01_READ_ONLY_BASELINE" -RunStatus "ready" -ActivePhase $null -ActiveScenario $null
  $extraCount.ExpectedDiagnosticCounts.Unexpected = 0
  Assert-LocalStableFailure -ExpectedCode "manifest_diagnostic_count_shape_rejected" -Operation { [void](Assert-ManifestRecord -Manifest $extraCount) }
  $nonintegerCount = New-LocalManifestFixture -CompletedPhase "PHASE_01_READ_ONLY_BASELINE" -RunStatus "ready" -ActivePhase $null -ActiveScenario $null
  $nonintegerCount.ExpectedDiagnosticCounts.Activities = "0"
  Assert-LocalStableFailure -ExpectedCode "manifest_diagnostic_count_type_rejected_activities" -Operation { [void](Assert-ManifestRecord -Manifest $nonintegerCount) }
  $missingProvenance = New-LocalManifestFixture -CompletedPhase "NONE" -RunStatus "ready" -ActivePhase $null -ActiveScenario $null
  $missingProvenance.Remove("SourceHead")
  Assert-LocalStableFailure -ExpectedCode "manifest_property_missing_sourcehead" -Operation { [void](Assert-ManifestRecord -Manifest $missingProvenance) }
  $textAttempt = New-LocalManifestFixture -CompletedPhase "NONE" -RunStatus "ready" -ActivePhase $null -ActiveScenario $null
  $textAttempt.AttemptNumber = "0"
  Assert-LocalStableFailure -ExpectedCode "resume_attempt_number_rejected" -Operation { [void](Assert-ManifestRecord -Manifest $textAttempt) }
  $runningWithoutPhase = New-LocalManifestFixture -CompletedPhase "PHASE_02_INSTALLATION_MATRIX" -RunStatus "running" -ActivePhase $null -ActiveScenario $null -ResultIds $phase02Ids
  Assert-LocalStableFailure -ExpectedCode "resume_running_phase_missing" -Operation { [void](Assert-ManifestRecord -Manifest $runningWithoutPhase) }
  Assert-LocalStableFailure -ExpectedCode "approved_evidence_missing" -Operation { [void](Assert-ManifestRecord -Manifest $approved) }
  Assert-LocalStableFailure -ExpectedCode "rejected_evidence_missing" -Operation { [void](Assert-ManifestRecord -Manifest $rejected) }
  Assert-LocalStableFailure -ExpectedCode "manifest_run_id_path_mismatch" -Operation { [void](Assert-ManifestRecord -Manifest (New-LocalManifestFixture -CompletedPhase "NONE" -RunStatus "ready" -ActivePhase $null -ActiveScenario $null) -ExpectedRunId "20260812T000001Z-00000001") }
}

function Assert-DiagnosticContractFixtures {
  $partial = [pscustomobject]@{
    DatabaseState = "UNKNOWN"; FingerprintAvailable = $false; PartialStateReason = "incomplete_0011_inventory"
    AuditTablePresent = $true; AdminListPresent = $false; CalendarLockHelperPresent = $true
    PeriodRpcPresence = @(1, 0, 0, 0, 0); TriggerPresence = @(1, 0, 0, 0, 0, 0, 0); ConstraintPresence = @(1, 0)
    Periods = 5; Activities = 1; FixturePeriods = 0; GrantedSem01AdvisoryLocks = 0; WaitingSem01AdvisoryLocks = 0
    TotalSem01AdvisoryLocks = 0; TransientWorkerSqlFiles = 0; OpenWorkers = 0; TemporaryObjects = 0; AuditEvents = 0
    State = $null; PeriodHash = $null; PeriodIdentityHash = $null; ExactAuthorities = $null; SyntheticAuthorities = $null
    AuthorityHash = $null; AssignmentHash = $null; ResolverHash = $null; BoundaryContractHash = $null
    FunctionInventoryCount = $null; FunctionInventoryHash = $null; FunctionInventoryValid = $null
    ExpectedTriggerMatchCount = $null; TriggerInventoryHash = $null; TriggerInventoryValid = $null
    ConstraintInventoryHash = $null; AuditConstraintCount = $null; AuditConstraintInventoryValid = $null
    IndexInventoryHash = $null; TableSecurityHash = $null; TableSecurityValid = $null; RoutineAclHash = $null; RoutineAclValid = $null
    NonexistentHelperCount = $null; CalendarLockHelperCount = $null; AuditTable = $null; AdminList = $null
    CompleteTriggerInventoryValid = $null; ActivitiesConstraintInventoryValid = $null; PeriodConstraintInventoryValid = $null
    CompleteAuditConstraintInventoryValid = $null; CompleteIndexInventoryValid = $null; TableAclContractValid = $null; RlsContractValid = $null; PolicyContractValid = $null
  }
  $manifest = New-LocalManifestFixture -CompletedPhase "PHASE_01_READ_ONLY_BASELINE" -RunStatus "ready" -ActivePhase $null -ActiveScenario $null
  $comparisons = [pscustomobject]@{
    StateMatches = $false; BaselineAvailable = $false; PeriodMatches = $false; AuthorityMatches = $false; AssignmentMatches = $false; Ms20CandidateSetMatches = $false
    ResolverApplicable = $false; ResolverMatches = $false; BoundaryApplicable = $false; BoundaryMatches = $false
    ActivityFixtureMatches = $true; RunIdMatches = $true; SourceHeadMatches = $true; MigrationHashMatches = $true; RollbackHashMatches = $true
    HarnessHashMatches = $true; HarnessVersionMatches = $true; ProtectedSourcesMatch = $true; EvidenceContractMatches = $true; PidFileCount = 0
    ApprovedPostcheckPublishing = $false; ApprovedEvidencePublishing = $false; FailurePostcheckPublishing = $false
    RejectedEvidencePublishing = $false; TotalPublishingArtifacts = 0
  }
  $lines = Get-PostcheckDiagnosticLines -Diagnostic $partial -Manifest $manifest -Comparisons $comparisons -StableCode "partial_database_state" -Clean $false
  foreach ($expectedLine in @("EXPECTED_FUNCTION_INVENTORY|NOT_APPLICABLE", "EXPECTED_TRIGGER_MATCHES|NOT_APPLICABLE", "AUDIT_CONSTRAINTS|NOT_APPLICABLE", "CANONICAL_PERIOD_ROWS|5", "FIXTURE_ACTIVITIES|1")) {
    Assert-Condition -Condition ($lines -ccontains $expectedLine) -Code "partial_diagnostic_renderer_fixture_rejected"
  }
  $full = (($partial | ConvertTo-Json -Depth 8 -Compress) | ConvertFrom-Json)
  $full.DatabaseState = "POST0011"
  $full.FingerprintAvailable = $true
  $full.PartialStateReason = $null
  $full.FunctionInventoryCount = 18
  $full.ExpectedTriggerMatchCount = 10
  $full.AuditConstraintCount = 7
  $fullLines = Get-PostcheckDiagnosticLines -Diagnostic $full -Manifest $manifest -Comparisons $comparisons -StableCode "database_state_mismatch" -Clean $false
  foreach ($expectedLine in @("EXPECTED_FUNCTION_INVENTORY|18", "EXPECTED_TRIGGER_MATCHES|10", "AUDIT_CONSTRAINTS|7")) {
    Assert-Condition -Condition ($fullLines -ccontains $expectedLine) -Code "full_diagnostic_renderer_fixture_rejected"
  }
  $temporary = Join-Path ([System.IO.Path]::GetTempPath()) ("sitaa-sem01-partial-" + [guid]::NewGuid().ToString("N") + ".txt")
  $rejectedAfterWrite = $false
  try {
    [System.IO.File]::WriteAllText($temporary, (($lines -join "`n") + "`n"), (New-Object System.Text.UTF8Encoding($false)))
    Throw-StableFailure -Code "postcheck_only_drift_or_residue_partial_database_state"
  }
  catch {
    $rejectedAfterWrite = (Test-Path -LiteralPath $temporary -PathType Leaf) -and $_.Exception.Message -ceq "postcheck_only_drift_or_residue_partial_database_state"
  }
  finally {
    Remove-Item -LiteralPath $temporary -Force -ErrorAction SilentlyContinue
  }
  Assert-Condition -Condition $rejectedAfterWrite -Code "partial_diagnostic_write_before_rejection_fixture_rejected"
}

function Assert-WorkerPidContractFixtures {
  [void](Assert-WorkerPidSetsAgree -ManifestPids @(101, 202) -PidFilePids @(202, 101))
  [void](Assert-WorkerPidSetsAgree -ManifestPids @(202) -PidFilePids @(202))
  Assert-LocalStableFailure -ExpectedCode "manifest_active_worker_pid_duplicate_rejected" -Operation { [void](Assert-WorkerPidSetsAgree -ManifestPids @(101, 101) -PidFilePids @(101)) }
  Assert-LocalStableFailure -ExpectedCode "worker_pid_sources_disagree" -Operation { [void](Assert-WorkerPidSetsAgree -ManifestPids @(101) -PidFilePids @(202)) }
}

function Assert-FrozenErrorRecordFixture {
  $classification = $null
  $code = $null
  try { Throw-StableFailure -Code "postgres_deadlock_40P01" -FailureClass "postgres_deadlock" }
  catch {
    $caughtError = $_
    try { throw "nested_diagnostic_failure" } catch { }
    $code = $caughtError.Exception.Message
    $classification = [string]$caughtError.Exception.Data["FailureClass"]
  }
  Assert-Condition -Condition ($code -ceq "postgres_deadlock_40P01" -and $classification -ceq "postgres_deadlock") -Code "frozen_error_record_fixture_rejected"
}

function Assert-PsqlTimeoutBindingDescriptor {
  param([Parameter(Mandatory = $true)][object]$Contract)
  Assert-Condition -Condition $Contract.InvokePsqlFileDeclaresTimeout -Code "psql_timeout_binding_fixture_rejected"
  Assert-Condition -Condition (-not $Contract.InvokePsqlFileUsesFreeTimeout) -Code "psql_timeout_binding_fixture_rejected"
  Assert-Condition -Condition (-not $Contract.InvokePsqlSqlUsesUnknownNamedTimeout) -Code "psql_timeout_binding_fixture_rejected"
  Assert-Condition -Condition (-not $Contract.StartPsqlWorkerOwnsTimeout) -Code "psql_timeout_binding_fixture_rejected"
  Assert-Condition -Condition $Contract.TimeoutResolvedBeforeStart -Code "psql_timeout_binding_fixture_rejected"
  Assert-Condition -Condition $Contract.WaitUsesResolvedTimeout -Code "psql_timeout_binding_fixture_rejected"
  Assert-Condition -Condition (-not $Contract.WaitUsesStatementOrLockTimeout) -Code "psql_timeout_binding_fixture_rejected"
  Assert-Condition -Condition $Contract.RepositoryTimeoutDeterministic -Code "psql_timeout_binding_fixture_rejected"
}

function Invoke-PsqlWorkerOwnershipFixture {
  param(
    [Parameter(Mandatory = $true)][scriptblock]$StartOperation,
    [Parameter(Mandatory = $true)][scriptblock]$WaitOperation,
    [Parameter(Mandatory = $true)][scriptblock]$StopOperation
  )
  $worker = $null
  $workerCollected = $false
  try {
    $worker = & $StartOperation
    $result = & $WaitOperation $worker
    $workerCollected = $true
    return $result
  }
  catch {
    $primaryError = $_
    if ($null -ne $worker -and -not $workerCollected) {
      [void](Invoke-SecondaryFailureOperation -Operation { & $StopOperation $worker })
    }
    throw $primaryError
  }
}

function Assert-PsqlProcessTimeoutContractFixtures {
  Assert-Condition -Condition ((Resolve-PsqlProcessTimeoutMilliseconds -StatementTimeoutMilliseconds 90000 -ProcessTimeoutMilliseconds 5000) -eq 5000) -Code "psql_explicit_timeout_5000_fixture_rejected"
  Assert-Condition -Condition ((Resolve-PsqlProcessTimeoutMilliseconds -StatementTimeoutMilliseconds 90000 -ProcessTimeoutMilliseconds 180000) -eq 180000) -Code "psql_explicit_timeout_180000_fixture_rejected"
  Assert-Condition -Condition ((Resolve-PsqlProcessTimeoutMilliseconds -StatementTimeoutMilliseconds 90000 -ProcessTimeoutMilliseconds 0) -eq 120000) -Code "psql_default_timeout_120000_fixture_rejected"
  Assert-Condition -Condition ((Resolve-PsqlProcessTimeoutMilliseconds -StatementTimeoutMilliseconds 180000 -ProcessTimeoutMilliseconds 0) -eq 210000) -Code "psql_default_timeout_210000_fixture_rejected"
  Assert-LocalStableFailure -ExpectedCode "psql_process_timeout_negative_rejected" -Operation {
    [void](Resolve-PsqlProcessTimeoutMilliseconds -StatementTimeoutMilliseconds 90000 -ProcessTimeoutMilliseconds -1)
  }
  Assert-LocalStableFailure -ExpectedCode "psql_process_timeout_range_rejected" -Operation {
    [void](Resolve-PsqlProcessTimeoutMilliseconds -StatementTimeoutMilliseconds 90000 -ProcessTimeoutMilliseconds 600001)
  }
  Assert-LocalStableFailure -ExpectedCode "psql_process_timeout_overflow_rejected" -Operation {
    [void](Resolve-PsqlProcessTimeoutMilliseconds -StatementTimeoutMilliseconds ([long]::MaxValue) -ProcessTimeoutMilliseconds 0)
  }

  $fileCommand = Get-Command Invoke-PsqlFile -CommandType Function
  $sqlCommand = Get-Command Invoke-PsqlSql -CommandType Function
  $startCommand = Get-Command Start-PsqlWorker -CommandType Function
  Assert-Condition -Condition $fileCommand.Parameters.ContainsKey("ProcessTimeoutMilliseconds") -Code "invoke_psql_file_timeout_parameter_fixture_rejected"
  Assert-Condition -Condition $sqlCommand.Parameters.ContainsKey("ProcessTimeoutMilliseconds") -Code "invoke_psql_sql_timeout_parameter_fixture_rejected"
  Assert-Condition -Condition (-not $startCommand.Parameters.ContainsKey("ProcessTimeoutMilliseconds")) -Code "start_psql_worker_timeout_owner_fixture_rejected"
  $fileTimeoutParameter = $fileCommand.Parameters["ProcessTimeoutMilliseconds"]
  $fileRange = @($fileTimeoutParameter.Attributes | Where-Object { $_ -is [System.Management.Automation.ValidateRangeAttribute] })
  Assert-Condition -Condition ($fileTimeoutParameter.ParameterType -eq [int] -and $fileRange.Count -eq 1 -and $fileRange[0].MinRange -eq 0 -and $fileRange[0].MaxRange -eq 600000) -Code "invoke_psql_file_timeout_metadata_fixture_rejected"
  $sqlRange = @($sqlCommand.Parameters["ProcessTimeoutMilliseconds"].Attributes | Where-Object { $_ -is [System.Management.Automation.ValidateRangeAttribute] })
  Assert-Condition -Condition ($sqlCommand.Parameters["ProcessTimeoutMilliseconds"].ParameterType -eq [int] -and $sqlRange.Count -eq 1 -and $sqlRange[0].MinRange -eq 0 -and $sqlRange[0].MaxRange -eq 600000) -Code "invoke_psql_sql_timeout_metadata_fixture_rejected"

  $fileDefinition = [string]$fileCommand.Definition
  $sqlDefinition = [string]$sqlCommand.Definition
  $exactDefinition = ([string](Get-Command Invoke-ExactRepositorySqlFile -CommandType Function).Definition) + "`n" + ([string](Get-Command Invoke-ExactRepositorySqlFileResult -CommandType Function).Definition)
  $resolveIndex = $fileDefinition.IndexOf("Resolve-PsqlProcessTimeoutMilliseconds", [System.StringComparison]::Ordinal)
  $startIndex = $fileDefinition.IndexOf("Start-PsqlWorker", [System.StringComparison]::Ordinal)
  $waitIndex = $fileDefinition.IndexOf("Wait-PsqlWorker", [System.StringComparison]::Ordinal)
  Assert-Condition -Condition ($resolveIndex -ge 0 -and $startIndex -gt $resolveIndex -and $waitIndex -gt $startIndex) -Code "psql_timeout_resolution_order_fixture_rejected"
  Assert-Condition -Condition ($fileDefinition.Contains('Wait-PsqlWorker -Worker $worker -TimeoutMilliseconds $effectiveProcessTimeout')) -Code "psql_wait_timeout_forwarding_fixture_rejected"
  Assert-Condition -Condition ($sqlDefinition.Contains('-ProcessTimeoutMilliseconds $ProcessTimeoutMilliseconds')) -Code "psql_sql_timeout_forwarding_fixture_rejected"
  Assert-Condition -Condition ($exactDefinition.Contains('-ProcessTimeoutMilliseconds $script:RepositorySqlProcessTimeoutMilliseconds') -and $script:RepositorySqlProcessTimeoutMilliseconds -eq 210000) -Code "repository_process_timeout_fixture_rejected"

  $positiveContract = [pscustomobject]@{
    InvokePsqlFileDeclaresTimeout = $true
    InvokePsqlFileUsesFreeTimeout = $false
    InvokePsqlSqlUsesUnknownNamedTimeout = $false
    StartPsqlWorkerOwnsTimeout = $false
    TimeoutResolvedBeforeStart = $true
    WaitUsesResolvedTimeout = $true
    WaitUsesStatementOrLockTimeout = $false
    RepositoryTimeoutDeterministic = $true
  }
  Assert-PsqlTimeoutBindingDescriptor -Contract $positiveContract
  foreach ($mutation in @(
    [pscustomobject]@{ Property = "InvokePsqlFileDeclaresTimeout"; Value = $false },
    [pscustomobject]@{ Property = "InvokePsqlFileUsesFreeTimeout"; Value = $true },
    [pscustomobject]@{ Property = "InvokePsqlSqlUsesUnknownNamedTimeout"; Value = $true },
    [pscustomobject]@{ Property = "StartPsqlWorkerOwnsTimeout"; Value = $true },
    [pscustomobject]@{ Property = "TimeoutResolvedBeforeStart"; Value = $false },
    [pscustomobject]@{ Property = "WaitUsesResolvedTimeout"; Value = $false },
    [pscustomobject]@{ Property = "WaitUsesStatementOrLockTimeout"; Value = $true },
    [pscustomobject]@{ Property = "RepositoryTimeoutDeterministic"; Value = $false }
  )) {
    $candidate = $positiveContract.PSObject.Copy()
    $candidate.PSObject.Properties[$mutation.Property].Value = $mutation.Value
    Assert-LocalStableFailure -ExpectedCode "psql_timeout_binding_fixture_rejected" -Operation {
      Assert-PsqlTimeoutBindingDescriptor -Contract $candidate
    }
  }
}

function Assert-PsqlWorkerOwnershipFixtures {
  $startCount = 0
  Assert-LocalStableFailure -ExpectedCode "psql_process_timeout_negative_rejected" -Operation {
    [void](Resolve-PsqlProcessTimeoutMilliseconds -StatementTimeoutMilliseconds 90000 -ProcessTimeoutMilliseconds -1)
    $startCount++
  }
  Assert-Condition -Condition ($startCount -eq 0) -Code "worker_started_before_timeout_validation_fixture_rejected"

  $events = New-Object System.Collections.ArrayList
  $cleanupState = [pscustomobject]@{ Count = 0 }
  $primaryCode = $null
  try {
    [void](Invoke-PsqlWorkerOwnershipFixture -StartOperation {
      return [pscustomobject]@{ Process = [pscustomobject]@{ HasExited = $false } }
    } -WaitOperation {
      param($worker)
      throw "fixture_primary_controller_failure"
    } -StopOperation {
      param($worker)
      $cleanupState.Count++
      $worker.Process.HasExited = $true
      [void]$events.Add("process_terminated")
      Assert-Condition -Condition $worker.Process.HasExited -Code "fixture_process_not_terminated"
      [void]$events.Add("pid_removal_attempted")
    })
  }
  catch { $primaryCode = $_.Exception.Message }
  Assert-Condition -Condition ($primaryCode -ceq "fixture_primary_controller_failure" -and $cleanupState.Count -eq 1) -Code "worker_primary_cleanup_fixture_rejected"
  Assert-Condition -Condition (($events -join "|") -ceq "process_terminated|pid_removal_attempted") -Code "worker_pid_removal_order_fixture_rejected"

  $cleanupFailurePrimary = $null
  try {
    [void](Invoke-PsqlWorkerOwnershipFixture -StartOperation {
      return [pscustomobject]@{ Process = [pscustomobject]@{ HasExited = $false } }
    } -WaitOperation { param($worker); throw "fixture_primary_preserved" } `
      -StopOperation { param($worker); $worker.Process.HasExited = $true; throw "fixture_secondary_cleanup_failure" })
  }
  catch { $cleanupFailurePrimary = $_.Exception.Message }
  Assert-Condition -Condition ($cleanupFailurePrimary -ceq "fixture_primary_preserved") -Code "worker_cleanup_replaced_primary_fixture_rejected"

  $normalStopState = [pscustomobject]@{ Count = 0 }
  $normal = Invoke-PsqlWorkerOwnershipFixture -StartOperation {
    return [pscustomobject]@{ Process = [pscustomobject]@{ HasExited = $false } }
  } -WaitOperation {
    param($worker)
    $worker.Process.HasExited = $true
    return "fixture_collected"
  } -StopOperation { param($worker); $normalStopState.Count++ }
  Assert-Condition -Condition ($normal -ceq "fixture_collected" -and $normalStopState.Count -eq 0) -Code "worker_double_stop_fixture_rejected"

  Assert-LocalStableFailure -ExpectedCode "worker_sql_delete_repository_rejected" -Operation {
    Assert-DisposableWorkerSqlPath -SqlFile $script:MigrationPath -RunDirectory $script:RepositoryRoot
  }
  $externalFixtureRoot = Join-Path ([System.IO.Path]::GetTempPath()) "sitaa-sem01-worker-lifecycle-fixture"
  Assert-DisposableWorkerSqlPath -SqlFile (Join-Path $externalFixtureRoot ("worker_fixture_" + ("a" * 32) + ".sql")) -RunDirectory $externalFixtureRoot
}

function Assert-TerminalArtifactContractFixtures {
  $root = Join-Path ([System.IO.Path]::GetTempPath()) ("sitaa-sem01-terminal-" + [guid]::NewGuid().ToString("N"))
  [System.IO.Directory]::CreateDirectory($root) | Out-Null
  $paths = [pscustomobject]@{
    Root = $root
    Evidence = Join-Path $root "multisession-evidence.local.txt"
    Failure = Join-Path $root "multisession-failure.local.txt"
    FinalPostcheck = Join-Path $root "final-postcheck.local.txt"
    FailurePostcheck = Join-Path $root "failure-postcheck.local.txt"
  }
  $encoding = New-Object System.Text.UTF8Encoding($false)
  $reset = {
    foreach ($path in @(
      $paths.Evidence, $paths.Failure, $paths.FinalPostcheck, $paths.FailurePostcheck,
      ($paths.Evidence + ".publishing"), ($paths.Failure + ".publishing"),
      ($paths.FinalPostcheck + ".publishing"), ($paths.FailurePostcheck + ".publishing")
    )) { Remove-Item -LiteralPath $path -Force -ErrorAction SilentlyContinue }
  }
  $fixtureError = $null
  $fixtureScenario = $null
  try {
    [System.IO.File]::WriteAllText($paths.FinalPostcheck, "FINAL_POSTCHECK|APPROVED`n", $encoding)
    [System.IO.File]::WriteAllText($paths.Evidence, "SEM01_0011_MULTISESSION|APPROVED`n", $encoding)
    $approved = Get-TerminalArtifactClassification -Inventory (Get-TerminalArtifactInventory -Paths $paths) -RunStatus "approved"
    Assert-Condition -Condition ($approved.EvidenceContractMatches -and $null -eq $approved.StableCode) -Code "approved_terminal_artifact_fixture_rejected"

    & $reset
    [System.IO.File]::WriteAllText($paths.FailurePostcheck, "FAILURE_POSTCHECK|RECORDED`n", $encoding)
    [System.IO.File]::WriteAllText($paths.Failure, "SEM01_0011_MULTISESSION|REJECTED|fixture`n", $encoding)
    $rejected = Get-TerminalArtifactClassification -Inventory (Get-TerminalArtifactInventory -Paths $paths) -RunStatus "rejected"
    Assert-Condition -Condition ($rejected.EvidenceContractMatches -and $null -eq $rejected.StableCode) -Code "rejected_terminal_artifact_fixture_rejected"

    & $reset
    [System.IO.File]::WriteAllText($paths.FinalPostcheck, "FINAL_POSTCHECK|APPROVED`n", $encoding)
    $partialApprovedManifestStatus = "running"
    $partialApprovedInventory = Get-TerminalArtifactInventory -Paths $paths
    $partialApproved = Get-TerminalArtifactClassification -Inventory $partialApprovedInventory -RunStatus "running"
    $rejectedEvidenceCreated = $false
    if (-not (Test-ApprovedFinalizationStarted -Inventory $partialApprovedInventory)) { $rejectedEvidenceCreated = $true }
    Assert-Condition -Condition ((Test-ApprovedFinalizationStarted -Inventory $partialApprovedInventory) -and -not $rejectedEvidenceCreated -and $partialApprovedManifestStatus -ceq "running" -and $partialApproved.StableCode -ceq "approval_finalization_incomplete") -Code "partial_approved_publication_fixture_rejected"

    & $reset
    [System.IO.File]::WriteAllText(($paths.FinalPostcheck + ".publishing"), "FINAL_POSTCHECK|APPROVED`n", $encoding)
    $approvedPublishing = Get-TerminalArtifactClassification -Inventory (Get-TerminalArtifactInventory -Paths $paths) -RunStatus "running"
    Assert-Condition -Condition ($approvedPublishing.StableCode -ceq "approval_publication_incomplete") -Code "approved_publishing_fixture_rejected"

    & $reset
    [System.IO.File]::WriteAllText(($paths.Failure + ".publishing"), "fixture`n", $encoding)
    $rejectedPublishing = Get-TerminalArtifactClassification -Inventory (Get-TerminalArtifactInventory -Paths $paths) -RunStatus "running"
    Assert-Condition -Condition ($rejectedPublishing.StableCode -ceq "rejection_publication_incomplete") -Code "rejected_publishing_fixture_rejected"

    [System.IO.File]::WriteAllText(($paths.Evidence + ".publishing"), "fixture`n", $encoding)
    $ambiguous = Get-TerminalArtifactClassification -Inventory (Get-TerminalArtifactInventory -Paths $paths) -RunStatus "running"
    Assert-Condition -Condition ($ambiguous.StableCode -ceq "ambiguous_terminal_artifacts") -Code "ambiguous_terminal_artifact_fixture_rejected"
  }
  catch {
    $fixtureError = $_
    $fixtureScenario = [string]$script:CurrentScenario
  }
  $fixtureCleanup = Invoke-OrchestrationCleanup -CleanupOperations @(
    [pscustomobject]@{ Name = "TERMINAL_FIXTURE_FILES_REMOVE"; Operation = { & $reset } },
    [pscustomobject]@{ Name = "TERMINAL_FIXTURE_DIRECTORY_REMOVE"; Operation = {
      if (Test-Path -LiteralPath $root -PathType Container) { [System.IO.Directory]::Delete($root, $false) }
    } }
  )
  Complete-OrchestrationCleanup -PrimaryError $fixtureError -PrimaryScenario $fixtureScenario -CleanupResult $fixtureCleanup `
    -CleanupFailureCode "terminal_fixture_cleanup_rejected"
}

function Assert-SecondaryFailurePreservationFixtures {
  $rethrown = $null
  $manifestState = "running"
  try {
    try { Throw-StableFailure -Code "postgres_deadlock_40P01" -FailureClass "postgres_deadlock" }
    catch {
      $caughtError = $_
      $failurePostcheck = Invoke-SecondaryFailureOperation -Operation { throw "failure_postcheck_fixture_failure" }
      $rejectedEvidence = Invoke-SecondaryFailureOperation -Operation { throw "rejected_evidence_fixture_failure" }
      $rejectedManifest = Invoke-SecondaryFailureOperation -Operation { throw "rejected_manifest_fixture_failure" }
      Assert-Condition -Condition (-not $failurePostcheck.Succeeded -and -not $rejectedEvidence.Succeeded -and -not $rejectedManifest.Succeeded) -Code "secondary_failure_guard_fixture_rejected"
      throw $caughtError
    }
  }
  catch { $rethrown = $_ }
  Assert-Condition -Condition ($null -ne $rethrown -and $rethrown.Exception.Message -ceq "postgres_deadlock_40P01" -and [string]$rethrown.Exception.Data["FailureClass"] -ceq "postgres_deadlock") -Code "secondary_failure_primary_error_fixture_rejected"
  Assert-Condition -Condition ($manifestState -ceq "running") -Code "secondary_failure_false_rejected_manifest_fixture_rejected"
}

function Invoke-OrchestrationCleanupFixture {
  param(
    [Parameter(Mandatory = $true)][string]$PrimaryCode,
    [Parameter(Mandatory = $true)][string]$PrimaryFailureClass,
    [Parameter(Mandatory = $true)][string]$PrimaryScenario,
    [Parameter(Mandatory = $true)][object[]]$CleanupOperations,
    [Parameter(Mandatory = $true)][object]$State,
    [Parameter(Mandatory = $true)][string]$CleanupFailureCode,
    [switch]$PrimarySucceeds
  )
  $primaryError = $null
  $frozenScenario = $null
  try {
    if (-not $PrimarySucceeds) {
      Set-CurrentScenario -ScenarioId $PrimaryScenario
      Throw-StableFailure -Code $PrimaryCode -FailureClass $PrimaryFailureClass
    }
  }
  catch {
    $primaryError = $_
    $frozenScenario = [string]$script:CurrentScenario
    $State.FrozenErrorRecord = $_
  }
  $cleanupResult = Invoke-OrchestrationCleanup -CleanupOperations $CleanupOperations
  $State.CleanupResult = $cleanupResult
  $State.PrimaryErrorRecordPreserved = ($null -eq $primaryError -or [object]::ReferenceEquals($State.FrozenErrorRecord, $primaryError))
  Complete-OrchestrationCleanup -PrimaryError $primaryError -PrimaryScenario $frozenScenario -CleanupResult $cleanupResult `
    -CleanupFailureCode $CleanupFailureCode
  return $cleanupResult
}

function Assert-OrchestrationCleanupContractFixtures {
  $primaryCases = @(
    [pscustomobject]@{ Code = "postgres_deadlock_40P01"; FailureClass = "postgres_deadlock"; Scenario = "MS11_OVERLAPPING_CREATIONS"; Cleanup = "HOLDER_STOP" },
    [pscustomobject]@{ Code = "observer_probe_late_success_rejected"; FailureClass = "worker_crash"; Scenario = "MS12_CREATE_VERSUS_CORRECTION"; Cleanup = "WAITER_STOP" },
    [pscustomobject]@{ Code = "ms18_future_start_rejection_missing"; FailureClass = "expected_business_rejection"; Scenario = "MS18_PUBLISH_WALL_CLOCK_AFTER_WAIT"; Cleanup = "FIXTURE_REMOVE" },
    [pscustomobject]@{ Code = "ms20_post_lock_authorization_rejected"; FailureClass = "expected_business_rejection"; Scenario = "MS20_AUTHORITY_LOSS_AFTER_WAIT"; Cleanup = "CLEANUP_CONNECTION" },
    [pscustomobject]@{ Code = "phase05_scenario_failure"; FailureClass = "postcondition_rejection"; Scenario = "MS17_POST_WAIT_RERESOLUTION"; Cleanup = "RUNTIME_FIXTURE_PROBE" }
  )
  foreach ($primaryCase in $primaryCases) {
    $state = [pscustomobject]@{
      Events = New-Object System.Collections.ArrayList
      FrozenErrorRecord = $null
      CleanupResult = $null
      PrimaryErrorRecordPreserved = $false
      FixtureRemoved = $false
    }
    $outerError = $null
    try {
      [void](Invoke-OrchestrationCleanupFixture -PrimaryCode $primaryCase.Code -PrimaryFailureClass $primaryCase.FailureClass `
        -PrimaryScenario $primaryCase.Scenario -CleanupFailureCode "fixture_cleanup_rejected" -State $state -CleanupOperations @(
          [pscustomobject]@{ Name = $primaryCase.Cleanup; Operation = {
            [void]$state.Events.Add("failing_cleanup_attempted")
            $script:CurrentScenario = "MS24_ZERO_RESIDUE"
            Throw-StableFailure -Code "secondary_cleanup_failure" -FailureClass "source_integrity_rejection"
            $state.FixtureRemoved = $true
          } },
          [pscustomobject]@{ Name = "LATER_CLEANUP"; Operation = { [void]$state.Events.Add("later_cleanup_attempted") } }
        ))
    }
    catch { $outerError = $_ }
    Assert-Condition -Condition ($null -ne $outerError -and $outerError.Exception.Message -ceq $primaryCase.Code) -Code "orchestration_primary_code_fixture_rejected"
    Assert-Condition -Condition ([string]$outerError.Exception.Data["FailureClass"] -ceq $primaryCase.FailureClass) -Code "orchestration_primary_class_fixture_rejected"
    Assert-Condition -Condition ([string]$script:CurrentScenario -ceq $primaryCase.Scenario) -Code "orchestration_primary_scenario_fixture_rejected"
    Assert-Condition -Condition ($state.PrimaryErrorRecordPreserved -and [object]::ReferenceEquals($state.FrozenErrorRecord.Exception, $outerError.Exception)) -Code "orchestration_primary_error_record_fixture_rejected"
    Assert-Condition -Condition (($state.Events -join "|") -ceq "failing_cleanup_attempted|later_cleanup_attempted") -Code "orchestration_all_cleanup_attempts_fixture_rejected"
    Assert-Condition -Condition (-not $state.CleanupResult.Succeeded -and @($state.CleanupResult.SecondaryErrors).Count -eq 1 -and
      [string]$state.CleanupResult.SecondaryErrors[0] -ceq $primaryCase.Cleanup) -Code "orchestration_secondary_result_fixture_rejected"
    Assert-Condition -Condition (-not $state.FixtureRemoved) -Code "orchestration_failed_cleanup_false_removal_fixture_rejected"
  }

  Clear-CurrentScenario
  $successState = [pscustomobject]@{
    Events = New-Object System.Collections.ArrayList
    FrozenErrorRecord = $null
    CleanupResult = $null
    PrimaryErrorRecordPreserved = $false
  }
  $successCleanupError = $null
  try {
    [void](Invoke-OrchestrationCleanupFixture -PrimaryCode "unused_primary_code" -PrimaryFailureClass "postcondition_rejection" `
      -PrimaryScenario "MS07_ADMIN_RPC_REJECTS_HIGH_ISOLATION" -CleanupFailureCode "successful_primary_cleanup_rejected" `
      -PrimarySucceeds -State $successState -CleanupOperations @(
        [pscustomobject]@{ Name = "SUCCESS_PATH_CLEANUP"; Operation = {
          [void]$successState.Events.Add("success_cleanup_attempted")
          throw "fixture_cleanup_failure"
        } }
      ))
  }
  catch { $successCleanupError = $_ }
  Assert-Condition -Condition ($null -ne $successCleanupError -and $successCleanupError.Exception.Message -ceq "successful_primary_cleanup_rejected" -and
    [string]$successCleanupError.Exception.Data["FailureClass"] -ceq "postcondition_rejection") -Code "successful_primary_cleanup_failure_fixture_rejected"
  Assert-Condition -Condition (($successState.Events -join "|") -ceq "success_cleanup_attempted") -Code "successful_primary_cleanup_attempt_fixture_rejected"

  $ownershipState = [pscustomobject]@{ Owned = $false; Worker = $null; Collected = $false; StopCount = 0; BeforeOwnershipCount = 0 }
  $ownershipCleanup = Invoke-OrchestrationCleanup -CleanupOperations @(
    [pscustomobject]@{ Name = "UNOWNED_WORKER"; Operation = {
      if ($ownershipState.Owned) { $ownershipState.BeforeOwnershipCount++ }
    } },
    [pscustomobject]@{ Name = "NULL_WORKER"; Operation = {
      if ($null -ne $ownershipState.Worker) { $ownershipState.StopCount++ }
    } },
    [pscustomobject]@{ Name = "COLLECTED_WORKER"; Operation = {
      $ownershipState.Owned = $true
      $ownershipState.Worker = [pscustomobject]@{ Process = [pscustomobject]@{ HasExited = $true } }
      $ownershipState.Collected = $true
      if ($null -ne $ownershipState.Worker -and -not $ownershipState.Collected) { $ownershipState.StopCount++ }
    } }
  )
  Assert-Condition -Condition ($ownershipCleanup.Succeeded -and $ownershipState.BeforeOwnershipCount -eq 0 -and
    $ownershipState.StopCount -eq 0) -Code "orchestration_idempotent_ownership_fixture_rejected"

  Clear-ConnectionMaterial -Connection $null
  $partialConnection = [pscustomobject]@{ Password = "fixture" }
  Clear-ConnectionMaterial -Connection $partialConnection
  Assert-Condition -Condition ($null -eq $partialConnection.Password) -Code "connection_cleanup_nonthrowing_fixture_rejected"
  Clear-CurrentScenario
}

function Assert-CleanupStatePropagationFixtures {
  $parentScalar = "parent"
  $returnedScalar = Invoke-SecondaryFailureOperation -Operation {
    $parentScalar = "child"
    return "returned"
  }
  Assert-Condition -Condition ($parentScalar -ceq "parent") -Code "child_scope_scalar_propagation_fixture_rejected"
  Assert-Condition -Condition ($returnedScalar.Succeeded -and [string]$returnedScalar.Value -ceq "returned") -Code "child_scope_return_consumption_fixture_rejected"

  $sharedState = [pscustomobject]@{ Value = "parent" }
  $sharedMutation = Invoke-SecondaryFailureOperation -Operation { $sharedState.Value = "child" }
  Assert-Condition -Condition ($sharedMutation.Succeeded -and $sharedState.Value -ceq "child") -Code "child_scope_object_property_fixture_rejected"

  $credentialState = [pscustomobject]@{
    Secure = (ConvertTo-SecureString "fixture" -AsPlainText -Force)
    Pointer = [Runtime.InteropServices.Marshal]::StringToBSTR("fixture")
    Plain = "fixture"
    PointerFreed = $false
    PointerFreeCount = 0
    TextReferencesCleared = $false
  }
  $credentialCleanup = Invoke-CredentialStateCleanup -CredentialState $credentialState
  Assert-Condition -Condition ($credentialCleanup.Succeeded -and $credentialState.Pointer -eq [IntPtr]::Zero -and
    $credentialState.PointerFreed -and $credentialState.PointerFreeCount -eq 1 -and $null -eq $credentialState.Plain -and
    $null -eq $credentialState.Secure -and $credentialState.TextReferencesCleared) -Code "credential_state_cleanup_fixture_rejected"

  $credentialPrimaryState = [pscustomobject]@{ Primary = $null; RethrowInput = $null; CleanupAttempted = $false }
  $credentialPrimaryCaught = $null
  try {
    try { Throw-StableFailure -Code "synthetic_connection_parse_failure" -FailureClass "source_integrity_rejection" }
    catch { $credentialPrimaryState.Primary = $_ }
    $failedCredentialCleanup = Invoke-OrchestrationCleanup -CleanupOperations @(
      [pscustomobject]@{ Name = "CREDENTIAL_SYNTHETIC_FAILURE"; Operation = {
        $credentialPrimaryState.CleanupAttempted = $true
        throw "synthetic_credential_cleanup_failure"
      } }
    )
    $credentialPrimaryState.RethrowInput = $credentialPrimaryState.Primary
    Complete-OrchestrationCleanup -PrimaryError $credentialPrimaryState.Primary -PrimaryScenario $null `
      -CleanupResult $failedCredentialCleanup -CleanupFailureCode "synthetic_credential_cleanup_rejected"
  }
  catch { $credentialPrimaryCaught = $_ }
  Assert-Condition -Condition ($credentialPrimaryState.CleanupAttempted -and
    [object]::ReferenceEquals($credentialPrimaryState.Primary, $credentialPrimaryState.RethrowInput) -and
    [object]::ReferenceEquals($credentialPrimaryState.Primary.Exception, $credentialPrimaryCaught.Exception)) `
    -Code "credential_primary_error_identity_fixture_rejected"

  $credentialSuccessCleanupError = $null
  try {
    $failedCredentialSuccessCleanup = Invoke-OrchestrationCleanup -CleanupOperations @(
      [pscustomobject]@{ Name = "CREDENTIAL_SUCCESS_SYNTHETIC_FAILURE"; Operation = { throw "synthetic_credential_cleanup_failure" } }
    )
    Complete-OrchestrationCleanup -PrimaryError $null -PrimaryScenario $null -CleanupResult $failedCredentialSuccessCleanup `
      -CleanupFailureCode "credential_success_cleanup_rejected"
  }
  catch { $credentialSuccessCleanupError = $_ }
  Assert-Condition -Condition ($null -ne $credentialSuccessCleanupError -and
    $credentialSuccessCleanupError.Exception.Message -ceq "credential_success_cleanup_rejected") -Code "credential_success_cleanup_failure_fixture_rejected"

  $fixtureRoot = Join-Path $script:EvidenceRoot ("validate-db19-" + [guid]::NewGuid().ToString("N"))
  $fixtureRootFull = [System.IO.Path]::GetFullPath($fixtureRoot)
  $evidenceRootFull = [System.IO.Path]::GetFullPath($script:EvidenceRoot).TrimEnd('\') + '\'
  Assert-Condition -Condition ($fixtureRootFull.StartsWith($evidenceRootFull, [System.StringComparison]::OrdinalIgnoreCase)) `
    -Code "external_file_fixture_root_rejected"
  [void][System.IO.Directory]::CreateDirectory($fixtureRootFull)
  $fileFixtureError = $null
  $fileFixtureScenario = $null
  try {
    $encoding = New-Object System.Text.UTF8Encoding($false)
    $content = "SEM01_DB19_FILE_FIXTURE|OK`n"
    $exclusivePath = Join-Path $fixtureRootFull "exclusive.local.txt"
    $exclusiveState = Invoke-ExclusiveExternalFileWrite -FullPath $exclusivePath -Content $content -Encoding $encoding
    Assert-Condition -Condition ($null -eq $exclusiveState.Writer -and $null -eq $exclusiveState.Stream -and
      $exclusiveState.WriterDisposed -and $exclusiveState.StreamDisposed) -Code "exclusive_file_state_fixture_rejected"
    Assert-Condition -Condition ([System.IO.File]::ReadAllText($exclusivePath, [System.Text.Encoding]::UTF8) -ceq $content -and
      (Get-Sha256 -Path $exclusivePath) -ceq "6f324fdefad92627e6bc93a44752e4c533241c30ad1d14d0e72de2f7ecf82589") `
      -Code "exclusive_file_content_fixture_rejected"
    $movedPath = Join-Path $fixtureRootFull "exclusive-moved.local.txt"
    Move-Item -LiteralPath $exclusivePath -Destination $movedPath
    Remove-Item -LiteralPath $movedPath -Force

    $sqlArtifact = New-SqlFile -RunDirectory $fixtureRootFull -Label "db19_fixture" -Sql "select 1;" -InitialOwner controller
    $sqlPath = $sqlArtifact.Path
    Assert-Condition -Condition ([System.IO.File]::ReadAllText($sqlPath, [System.Text.Encoding]::UTF8) -ceq "select 1;`n") `
      -Code "new_sql_file_cleanup_fixture_rejected"
    Remove-Item -LiteralPath $sqlPath -Force

    $constructorPath = Join-Path $fixtureRootFull "writer-construction.local.txt"
    $constructorState = [pscustomobject]@{
      Stream = $null; Writer = $null; StreamOwned = $false; WriterOwned = $false
      WriterDisposed = $false; StreamDisposed = $false
    }
    $constructorPrimary = $null
    $constructorCaught = $null
    try {
      $constructorState.Stream = New-Object System.IO.FileStream($constructorPath, [System.IO.FileMode]::CreateNew, [System.IO.FileAccess]::Write, [System.IO.FileShare]::None)
      $constructorState.StreamOwned = $true
      Throw-StableFailure -Code "synthetic_writer_construction_failure" -FailureClass "source_integrity_rejection"
    }
    catch { $constructorPrimary = $_ }
    $constructorCleanup = Invoke-ExternalFileStateCleanup -FileState $constructorState
    try {
      Complete-OrchestrationCleanup -PrimaryError $constructorPrimary -PrimaryScenario $null -CleanupResult $constructorCleanup `
        -CleanupFailureCode "writer_construction_cleanup_rejected"
    }
    catch { $constructorCaught = $_ }
    Assert-Condition -Condition ([object]::ReferenceEquals($constructorPrimary.Exception, $constructorCaught.Exception) -and
      $constructorState.StreamOwned -and $constructorState.StreamDisposed -and $null -eq $constructorState.Stream) `
      -Code "writer_construction_primary_preservation_fixture_rejected"
    $constructorMovedPath = Join-Path $fixtureRootFull "writer-construction-moved.local.txt"
    Move-Item -LiteralPath $constructorPath -Destination $constructorMovedPath
    Remove-Item -LiteralPath $constructorMovedPath -Force

    $fakeWriter = [pscustomobject]@{ DisposeAttempts = 0 }
    $fakeWriter | Add-Member -MemberType ScriptMethod -Name Dispose -Value {
      $this.DisposeAttempts++
      throw "synthetic_writer_disposal_failure"
    }
    $fakeStream = [pscustomobject]@{ DisposeAttempts = 0 }
    $fakeStream | Add-Member -MemberType ScriptMethod -Name Dispose -Value { $this.DisposeAttempts++ }
    $disposalState = [pscustomobject]@{
      Stream = $fakeStream; Writer = $fakeWriter; StreamOwned = $true; WriterOwned = $true
      WriterDisposed = $false; StreamDisposed = $false
    }
    $disposalCleanup = Invoke-ExternalFileStateCleanup -FileState $disposalState
    Assert-Condition -Condition (-not $disposalCleanup.Succeeded -and $fakeWriter.DisposeAttempts -eq 1 -and
      $fakeStream.DisposeAttempts -eq 1 -and $null -eq $disposalState.Writer -and $null -eq $disposalState.Stream -and
      $disposalState.StreamDisposed) -Code "writer_disposal_independent_stream_cleanup_fixture_rejected"
    $disposalSuccessCaught = $null
    try {
      Complete-OrchestrationCleanup -PrimaryError $null -PrimaryScenario $null -CleanupResult $disposalCleanup `
        -CleanupFailureCode "file_success_cleanup_rejected"
    }
    catch { $disposalSuccessCaught = $_ }
    Assert-Condition -Condition ($null -ne $disposalSuccessCaught -and
      $disposalSuccessCaught.Exception.Message -ceq "file_success_cleanup_rejected") `
      -Code "file_success_cleanup_failure_fixture_rejected"
    $disposalPrimary = $null
    $disposalCaught = $null
    try { Throw-StableFailure -Code "synthetic_primary_write_failure" -FailureClass "source_integrity_rejection" }
    catch { $disposalPrimary = $_ }
    try {
      Complete-OrchestrationCleanup -PrimaryError $disposalPrimary -PrimaryScenario $null -CleanupResult $disposalCleanup `
        -CleanupFailureCode "writer_disposal_cleanup_rejected"
    }
    catch { $disposalCaught = $_ }
    Assert-Condition -Condition ([object]::ReferenceEquals($disposalPrimary.Exception, $disposalCaught.Exception)) `
      -Code "writer_disposal_primary_error_identity_fixture_rejected"
  }
  catch {
    $fileFixtureError = $_
    $fileFixtureScenario = [string]$script:CurrentScenario
  }
  $fileFixtureState = [pscustomobject]@{ Removed = $false }
  $fileFixtureCleanup = Invoke-OrchestrationCleanup -CleanupOperations @(
    [pscustomobject]@{ Name = "DB19_EXTERNAL_FIXTURE_REMOVE"; Operation = {
      if (Test-Path -LiteralPath $fixtureRootFull -PathType Container) { [System.IO.Directory]::Delete($fixtureRootFull, $true) }
      $fileFixtureState.Removed = -not (Test-Path -LiteralPath $fixtureRootFull)
    } }
  )
  Complete-OrchestrationCleanup -PrimaryError $fileFixtureError -PrimaryScenario $fileFixtureScenario -CleanupResult $fileFixtureCleanup `
    -CleanupFailureCode "db19_external_fixture_cleanup_rejected"
  Assert-Condition -Condition $fileFixtureState.Removed -Code "db19_external_fixture_cleanup_postcondition_rejected"
}

function New-SyntheticStagedStartOwnershipState {
  param([Parameter(Mandatory = $true)][string]$Pattern)
  return [pscustomobject]@{
    Pattern = $Pattern
    Process = $null
    ProcessStarted = $false
    Worker = $null
    StdoutTaskReady = $false
    StartInfoMaterialClearAttempted = $false
    StartInfoMaterialCleared = $false
    LocalPidAddAttempted = $false
    LocalPidRecorded = $false
    ExecutePidAddAttempted = $false
    ExecutePidRecorded = $false
    LocalPidRemovalAttempted = $false
    ExecutePidRemovalAttempted = $false
    ProcessTerminationAttempted = $false
    ProcessTerminationObserved = $false
    LocalPidRemovalFails = $false
    ExecutePidRemovalFails = $false
    PrimaryErrorRecord = $null
    RethrowErrorRecord = $null
    CleanupResult = $null
  }
}

function Invoke-SyntheticStagedStartOwnershipModel {
  param(
    [Parameter(Mandatory = $true)][object]$State,
    [Parameter(Mandatory = $true)][ValidateSet("before_start", "after_start", "stdout_task", "worker_construction", "start_info_clear", "execute_pid_add", "success")][string]$FailurePoint
  )
  $primaryError = $null
  try {
    if ($FailurePoint -ceq "before_start") { Throw-StableFailure -Code "synthetic_pre_start_failure" -FailureClass "worker_crash" }
    $State.Process = [pscustomobject]@{ HasExited = $false }
    $State.ProcessStarted = $true
    if ($FailurePoint -ceq "after_start") { Throw-StableFailure -Code "synthetic_post_start_failure" -FailureClass "worker_crash" }
    if ($FailurePoint -ceq "stdout_task") { Throw-StableFailure -Code "synthetic_stdout_task_failure" -FailureClass "worker_crash" }
    $State.StdoutTaskReady = $true
    if ($FailurePoint -ceq "worker_construction") { Throw-StableFailure -Code "synthetic_worker_construction_failure" -FailureClass "worker_crash" }
    $State.Worker = [pscustomobject]@{ Complete = $false; PidSourcesSynchronized = $false }
    if ($FailurePoint -ceq "start_info_clear") { Throw-StableFailure -Code "synthetic_start_info_clear_failure" -FailureClass "worker_crash" }
    $State.StartInfoMaterialCleared = $true
    $State.LocalPidAddAttempted = $true
    $State.LocalPidRecorded = $true
    $State.ExecutePidAddAttempted = $true
    if ($FailurePoint -ceq "execute_pid_add") { Throw-StableFailure -Code "synthetic_execute_pid_add_failure" -FailureClass "worker_crash" }
    $State.ExecutePidRecorded = $true
    $State.Worker.Complete = $true
    $State.Worker.PidSourcesSynchronized = $true
    return $State.Worker
  }
  catch {
    $primaryError = $_
    $State.PrimaryErrorRecord = $_
    $State.CleanupResult = Invoke-OrchestrationCleanup -CleanupOperations @(
      [pscustomobject]@{ Name = "SYNTHETIC_PROCESS_TERMINATE"; Operation = {
        if ($State.ProcessStarted -and $null -ne $State.Process) {
          $State.ProcessTerminationAttempted = $true
          $State.Process.HasExited = $true
          $State.ProcessTerminationObserved = $true
        }
      } },
      [pscustomobject]@{ Name = "SYNTHETIC_LOCAL_PID_REMOVE"; Operation = {
        if ($State.LocalPidAddAttempted) {
          $State.LocalPidRemovalAttempted = $true
          Assert-Condition -Condition $State.ProcessTerminationObserved -Code "synthetic_pid_removed_before_exit"
          if ($State.LocalPidRemovalFails) { throw "synthetic_local_pid_removal_failure" }
          $State.LocalPidRecorded = $false
        }
      } },
      [pscustomobject]@{ Name = "SYNTHETIC_EXECUTE_PID_REMOVE"; Operation = {
        if ($State.ExecutePidAddAttempted) {
          $State.ExecutePidRemovalAttempted = $true
          Assert-Condition -Condition $State.ProcessTerminationObserved -Code "synthetic_pid_removed_before_exit"
          if ($State.ExecutePidRemovalFails) { throw "synthetic_execute_pid_removal_failure" }
          $State.ExecutePidRecorded = $false
        }
      } }
    )
    $State.RethrowErrorRecord = $primaryError
    throw $primaryError
  }
}

function Assert-StagedStartOwnershipFixtures {
  foreach ($pattern in @("Start-StagedInstallationHolder", "Start-StagedAuthorityLossHolder", "Start-PersistentInstallationObserver")) {
    foreach ($failurePoint in @("before_start", "after_start", "stdout_task", "worker_construction", "start_info_clear")) {
      $state = New-SyntheticStagedStartOwnershipState -Pattern $pattern
      $caught = $null
      try { [void](Invoke-SyntheticStagedStartOwnershipModel -State $state -FailurePoint $failurePoint) }
      catch { $caught = $_ }
      $workerShapeValid = if ($failurePoint -ceq "start_info_clear") { $null -ne $state.Worker -and -not $state.Worker.Complete } else { $null -eq $state.Worker }
      Assert-Condition -Condition ($null -ne $caught -and [object]::ReferenceEquals($state.PrimaryErrorRecord, $state.RethrowErrorRecord) -and
        [object]::ReferenceEquals($state.PrimaryErrorRecord.Exception, $caught.Exception) -and $workerShapeValid) `
        -Code "staged_start_primary_error_identity_fixture_rejected"
      if ($failurePoint -ceq "before_start") {
        Assert-Condition -Condition (-not $state.ProcessStarted -and -not $state.ProcessTerminationAttempted) -Code "staged_start_pre_start_ownership_fixture_rejected"
      }
      else {
        Assert-Condition -Condition ($state.ProcessTerminationAttempted -and $state.ProcessTerminationObserved -and $state.Process.HasExited) `
          -Code "staged_start_post_start_termination_fixture_rejected"
      }
      Assert-Condition -Condition ($null -eq $caught -or $null -eq $state.Worker -or -not $state.Worker.Complete) `
        -Code "staged_start_partial_worker_return_fixture_rejected"
    }

    $secondPidFailureState = New-SyntheticStagedStartOwnershipState -Pattern $pattern
    $secondPidFailureCaught = $null
    try { [void](Invoke-SyntheticStagedStartOwnershipModel -State $secondPidFailureState -FailurePoint "execute_pid_add") }
    catch { $secondPidFailureCaught = $_ }
    Assert-Condition -Condition ([object]::ReferenceEquals($secondPidFailureState.PrimaryErrorRecord, $secondPidFailureState.RethrowErrorRecord) -and
      [object]::ReferenceEquals($secondPidFailureState.PrimaryErrorRecord.Exception, $secondPidFailureCaught.Exception) -and
      $secondPidFailureState.ProcessTerminationObserved -and $secondPidFailureState.LocalPidRemovalAttempted -and
      $secondPidFailureState.ExecutePidRemovalAttempted -and -not $secondPidFailureState.LocalPidRecorded) `
      -Code "staged_start_second_pid_failure_cleanup_fixture_rejected"

    $localRemovalFailureState = New-SyntheticStagedStartOwnershipState -Pattern $pattern
    $localRemovalFailureState.LocalPidRemovalFails = $true
    $localRemovalFailureCaught = $null
    try { [void](Invoke-SyntheticStagedStartOwnershipModel -State $localRemovalFailureState -FailurePoint "execute_pid_add") }
    catch { $localRemovalFailureCaught = $_ }
    Assert-Condition -Condition ([object]::ReferenceEquals($localRemovalFailureState.PrimaryErrorRecord, $localRemovalFailureState.RethrowErrorRecord) -and
      [object]::ReferenceEquals($localRemovalFailureState.PrimaryErrorRecord.Exception, $localRemovalFailureCaught.Exception) -and
      $localRemovalFailureState.LocalPidRemovalAttempted -and $localRemovalFailureState.ExecutePidRemovalAttempted) `
      -Code "staged_start_local_removal_independence_fixture_rejected"

    $executeRemovalFailureState = New-SyntheticStagedStartOwnershipState -Pattern $pattern
    $executeRemovalFailureState.ExecutePidRemovalFails = $true
    $executeRemovalFailureCaught = $null
    try { [void](Invoke-SyntheticStagedStartOwnershipModel -State $executeRemovalFailureState -FailurePoint "execute_pid_add") }
    catch { $executeRemovalFailureCaught = $_ }
    Assert-Condition -Condition ([object]::ReferenceEquals($executeRemovalFailureState.PrimaryErrorRecord, $executeRemovalFailureState.RethrowErrorRecord) -and
      [object]::ReferenceEquals($executeRemovalFailureState.PrimaryErrorRecord.Exception, $executeRemovalFailureCaught.Exception) -and
      $executeRemovalFailureState.ExecutePidRemovalAttempted) -Code "staged_start_execute_removal_primary_preservation_fixture_rejected"

    $successState = New-SyntheticStagedStartOwnershipState -Pattern $pattern
    $completeWorker = Invoke-SyntheticStagedStartOwnershipModel -State $successState -FailurePoint "success"
    Assert-Condition -Condition ($null -ne $completeWorker -and $completeWorker.Complete -and $completeWorker.PidSourcesSynchronized -and
      $successState.LocalPidRecorded -and $successState.ExecutePidRecorded -and -not $successState.ProcessTerminationAttempted) `
      -Code "staged_start_complete_worker_fixture_rejected"
  }
}

function Assert-FailureScenarioContractFixtures {
  Clear-CurrentScenario
  Assert-Condition -Condition ((Get-FailureScenario) -ceq "NONE") -Code "phase_only_failure_scenario_fixture_rejected"
  Set-CurrentScenario -ScenarioId "MS07_ADMIN_RPC_REJECTS_HIGH_ISOLATION"
  Assert-Condition -Condition ((Get-FailureScenario) -ceq "MS07_ADMIN_RPC_REJECTS_HIGH_ISOLATION") -Code "active_failure_scenario_fixture_rejected"
  Clear-CurrentScenario
  Assert-Condition -Condition ((Get-FailureScenario) -ceq "NONE") -Code "cleared_failure_scenario_fixture_rejected"
}

function Update-WorkerPidManifest {
  param(
    [Parameter(Mandatory = $true)][string]$RunDirectory,
    [Parameter(Mandatory = $true)][int]$ProcessId,
    [Parameter(Mandatory = $true)][string]$ApplicationName,
    [Parameter(Mandatory = $true)][ValidateSet("add", "remove")][string]$Operation
  )
  $path = Join-Path $RunDirectory "worker-pids.local.json"
  $workers = @()
  if (Test-Path -LiteralPath $path -PathType Leaf) {
    $loaded = Get-Content -LiteralPath $path -Raw -Encoding utf8 | ConvertFrom-Json
    $workers = @($loaded.Workers)
  }
  $workers = @($workers | Where-Object { [int]$_.Pid -ne $ProcessId })
  if ($Operation -eq "add") {
    $workers += [pscustomobject]@{ Pid = $ProcessId; ApplicationName = $ApplicationName }
  }
  if ($workers.Count -eq 0) {
    Remove-Item -LiteralPath $path -Force -ErrorAction SilentlyContinue
    return
  }
  $payload = [ordered]@{ HarnessVersion = $script:HarnessVersion; Workers = $workers }
  Write-ExternalUtf8File -Path $path -Content (($payload | ConvertTo-Json -Depth 4) + "`n")
}

function Get-WorkerPidManifestValues {
  param([Parameter(Mandatory = $true)][string]$RunDirectory)
  $path = Join-Path $RunDirectory "worker-pids.local.json"
  if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { return @() }
  $loaded = Get-Content -LiteralPath $path -Raw -Encoding utf8 | ConvertFrom-Json
  return @($loaded.Workers | ForEach-Object { [int]$_.Pid })
}

function Assert-WorkerPidSetsAgree {
  param(
    [Parameter(Mandatory = $true)][int[]]$ManifestPids,
    [Parameter(Mandatory = $true)][int[]]$PidFilePids
  )
  Assert-Condition -Condition ($ManifestPids.Count -eq @($ManifestPids | Sort-Object -Unique).Count) -Code "manifest_active_worker_pid_duplicate_rejected"
  Assert-Condition -Condition ($PidFilePids.Count -eq @($PidFilePids | Sort-Object -Unique).Count) -Code "worker_pid_file_duplicate_rejected"
  Assert-Condition -Condition ((@($ManifestPids | Sort-Object) -join "|") -ceq (@($PidFilePids | Sort-Object) -join "|")) -Code "worker_pid_sources_disagree"
}

function Update-ExecuteWorkerManifest {
  param(
    [AllowNull()][object]$ExecutionContext,
    [Parameter(Mandatory = $true)][int]$ProcessId,
    [Parameter(Mandatory = $true)][ValidateSet("add", "remove")][string]$Operation
  )
  if ($null -eq $ExecutionContext) { return }
  $manifest = $ExecutionContext.Manifest
  $paths = $ExecutionContext.Paths
  $pids = @($manifest.ActiveWorkerPids | ForEach-Object { [int]$_ } | Where-Object { $_ -ne $ProcessId })
  if ($Operation -ceq "add") { $pids += $ProcessId }
  $manifest.ActiveWorkerPids = @($pids | Sort-Object -Unique)
  Assert-WorkerPidSetsAgree -ManifestPids @($manifest.ActiveWorkerPids) -PidFilePids @(Get-WorkerPidManifestValues -RunDirectory $paths.Root)
  Write-Manifest -Paths $paths -Manifest $manifest
}

function Remove-ApprovedTransientFiles {
  param([Parameter(Mandatory = $true)][object]$Paths)
  $evidenceRoot = [System.IO.Path]::GetFullPath($script:EvidenceRoot).TrimEnd('\') + '\'
  Assert-Condition -Condition ([System.IO.Path]::GetFullPath($Paths.Root).StartsWith($evidenceRoot, [System.StringComparison]::OrdinalIgnoreCase)) -Code "transient_cleanup_root_rejected"
  foreach ($pattern in @("worker_*.sql", "raw_*.stdout.local.txt", "raw_*.stderr.local.txt")) {
    foreach ($item in @(Get-ChildItem -LiteralPath $Paths.Root -Filter $pattern -File -ErrorAction Stop)) {
      if ($item.Extension -eq ".sql") {
        Assert-DisposableWorkerSqlPath -SqlFile $item.FullName -RunDirectory $Paths.Root
      }
      Remove-Item -LiteralPath $item.FullName -Force
    }
  }
  if (Test-Path -LiteralPath $Paths.WorkerManifest -PathType Leaf) {
    Remove-Item -LiteralPath $Paths.WorkerManifest -Force
  }
}

function Assert-ManifestExecuteEligibility {
  param(
    [Parameter(Mandatory = $true)][object]$Manifest,
    [bool]$HasRejectedEvidence = $false,
    [bool]$HasApprovedEvidence = $false,
    [bool]$HasFinalPostcheckEvidence = $false,
    [bool]$HasFailurePostcheckEvidence = $false,
    [ValidateRange(0, 4)][int]$TotalPublishingArtifacts = 0
  )
  if ([string]$Manifest.RunStatus -ceq "running" -or $null -ne $Manifest.ActivePhase) {
    Throw-StableFailure -Code "resume_incomplete_phase_rejected" -FailureClass "baseline_rejection"
  }
  if ([string]$Manifest.RunStatus -ceq "rejected" -or $HasRejectedEvidence) {
    Throw-StableFailure -Code "resume_rejected_run_rejected" -FailureClass "baseline_rejection"
  }
  Assert-Condition -Condition ([string]$Manifest.RunStatus -ceq "ready") -Code "resume_run_not_ready" -FailureClass "baseline_rejection"
  Assert-Condition -Condition (-not $HasApprovedEvidence -and -not $HasFinalPostcheckEvidence -and -not $HasFailurePostcheckEvidence) -Code "resume_terminal_evidence_rejected" -FailureClass "baseline_rejection"
  Assert-Condition -Condition ($TotalPublishingArtifacts -eq 0) -Code "resume_terminal_publication_incomplete" -FailureClass "baseline_rejection"
  $completedIndex = Get-PhaseIndex -Phase ([string]$Manifest.CompletedPhase)
  Assert-Condition -Condition ($completedIndex -ge 1 -and $completedIndex -le 5) -Code "resume_completed_boundary_missing" -FailureClass "baseline_rejection"
  Assert-Condition -Condition (@($Manifest.ActiveWorkerPids).Count -eq 0) -Code "resume_manifest_workers_active" -FailureClass "baseline_rejection"
}

function Start-ManifestPhase {
  param(
    [Parameter(Mandatory = $true)][object]$Manifest,
    [Parameter(Mandatory = $true)][object]$Paths,
    [Parameter(Mandatory = $true)][string]$Phase,
    [switch]$IncrementAttempt
  )
  Clear-CurrentScenario
  Assert-Condition -Condition ([string]$Manifest.RunStatus -ceq "ready" -and $null -eq $Manifest.ActivePhase -and $null -eq $Manifest.ActiveScenario) -Code "phase_start_state_rejected"
  Assert-Condition -Condition (-not (Test-Path -LiteralPath $Paths.Failure -PathType Leaf)) -Code "phase_start_rejected_evidence_rejected"
  Assert-Condition -Condition (-not (Test-Path -LiteralPath $Paths.Evidence -PathType Leaf)) -Code "phase_start_approved_evidence_rejected"
  $completedIndex = Get-PhaseIndex -Phase ([string]$Manifest.CompletedPhase)
  $phaseIndex = Get-PhaseIndex -Phase $Phase
  Assert-Condition -Condition ($phaseIndex -eq (Get-NextRemotePhaseIndex -CompletedPhase ([string]$Manifest.CompletedPhase))) -Code "phase_start_order_rejected"
  $phaseScenarios = @(Get-ScenarioIdsForPhase -Phase $Phase)
  $Manifest.RunStatus = "running"
  $Manifest.ActivePhase = $Phase
  $Manifest.ActiveScenario = if ($phaseScenarios.Count -gt 0) { $phaseScenarios[0] } else { $null }
  if ($IncrementAttempt) { $Manifest.AttemptNumber = [int]$Manifest.AttemptNumber + 1 }
  Write-Manifest -Paths $Paths -Manifest $Manifest
}

function Assert-ResumeContract {
  param(
    [Parameter(Mandatory = $true)][object]$Manifest,
    [Parameter(Mandatory = $true)][object]$Connection,
    [Parameter(Mandatory = $true)][string]$PsqlPath,
    [Parameter(Mandatory = $true)][object]$Paths
  )
  $artifacts = Get-TerminalArtifactInventory -Paths $Paths
  Assert-ManifestExecuteEligibility -Manifest $Manifest -HasRejectedEvidence $artifacts.RejectedEvidenceExists -HasApprovedEvidence $artifacts.ApprovedEvidenceExists `
    -HasFinalPostcheckEvidence $artifacts.ApprovedPostcheckExists -HasFailurePostcheckEvidence $artifacts.FailurePostcheckExists -TotalPublishingArtifacts $artifacts.TotalPublishingArtifacts
  $pidFilePids = @(Get-WorkerPidManifestValues -RunDirectory $Paths.Root)
  Assert-WorkerPidSetsAgree -ManifestPids @($Manifest.ActiveWorkerPids) -PidFilePids $pidFilePids
  Assert-Condition -Condition (@($Manifest.ActiveWorkerPids).Count -eq 0 -and $pidFilePids.Count -eq 0) -Code "resume_workers_active"
  Assert-Condition -Condition ($Manifest.SourceHead -eq (Get-SourceHead)) -Code "resume_source_head_rejected"
  Assert-Condition -Condition ($Manifest.MigrationSha256 -eq (Get-Sha256 -Path $script:MigrationPath)) -Code "resume_migration_hash_rejected"
  Assert-Condition -Condition ($Manifest.RollbackSha256 -eq (Get-Sha256 -Path $script:RollbackPath)) -Code "resume_rollback_hash_rejected"
  Assert-Condition -Condition ($Manifest.HarnessSha256 -eq (Get-Sha256 -Path $PSCommandPath)) -Code "resume_harness_hash_rejected"
  $postcheck = Invoke-ReadOnlyDatabasePostcheck -Connection $Connection -PsqlPath $PsqlPath -RunDirectory $Paths.Root
  Assert-Condition -Condition ($postcheck.DatabaseState -eq $Manifest.ExpectedDatabaseState) -Code "resume_phase_boundary_rejected"
  Assert-Condition -Condition ($null -ne $Manifest.ExpectedDiagnosticCounts) -Code "resume_diagnostic_counts_missing"
  Assert-Condition -Condition (
    $postcheck.FixturePeriods -eq [int]$Manifest.ExpectedDiagnosticCounts.FixturePeriods -and
    $postcheck.Activities -eq [int]$Manifest.ExpectedDiagnosticCounts.Activities -and
    $postcheck.AuditEvents -eq [int]$Manifest.ExpectedDiagnosticCounts.AuditEvents -and
    $postcheck.OpenWorkers -eq [int]$Manifest.ExpectedDiagnosticCounts.OpenWorkers -and
    $postcheck.GrantedSem01AdvisoryLocks -eq [int]$Manifest.ExpectedDiagnosticCounts.GrantedSem01AdvisoryLocks -and
    $postcheck.WaitingSem01AdvisoryLocks -eq [int]$Manifest.ExpectedDiagnosticCounts.WaitingSem01AdvisoryLocks -and
    $postcheck.TotalSem01AdvisoryLocks -eq [int]$Manifest.ExpectedDiagnosticCounts.TotalSem01AdvisoryLocks -and
    $postcheck.TransientWorkerSqlFiles -eq [int]$Manifest.ExpectedDiagnosticCounts.TransientWorkerSqlFiles -and
    $postcheck.TemporaryObjects -eq [int]$Manifest.ExpectedDiagnosticCounts.TemporaryObjects
  ) -Code "resume_boundary_residue_rejected"
  if ($null -ne $Manifest.ExpectedActivityFixture) {
    $activityFixture = Get-ActivityFixtureSnapshot -Connection $Connection -PsqlPath $PsqlPath -RunDirectory $Paths.Root -ActivityId ([string]$Manifest.ExpectedActivityFixture.Id)
    Assert-Condition -Condition ($activityFixture.Activities -eq 1 -and $activityFixture.MatchingRows -eq 1) -Code "resume_activity_fixture_count_rejected"
    Assert-Condition -Condition ($activityFixture.RowFingerprint -ceq [string]$Manifest.ExpectedActivityFixture.RowFingerprint) -Code "resume_activity_fixture_fingerprint_rejected"
  }
  else {
    Assert-Condition -Condition ($postcheck.Activities -eq 0) -Code "resume_unexpected_activity_rejected"
  }
  Assert-FingerprintPreserved -Observed $postcheck -Expected $Manifest.BaselineFingerprint
  if ($Manifest.ExpectedDatabaseState -ceq "POST0010") {
    Assert-FingerprintPreserved -Observed $postcheck -Expected $Manifest.BaselineFingerprint -IncludeResolver -IncludeBoundaryContract
  }
  else {
    Assert-FingerprintPreserved -Observed $postcheck -Expected $Manifest.Post0011Fingerprint -IncludeResolver -IncludeBoundaryContract
  }
}

function Invoke-TransientSqlPathCleanup {
  param(
    [Parameter(Mandatory = $true)][object]$CreationState,
    [Parameter(Mandatory = $true)][string]$RunDirectory
  )
  $CreationState.RemovalAttempted = $true
  $cleanup = Invoke-OrchestrationCleanup -EmitFailureMarkers -CleanupOperations @(
    [pscustomobject]@{ Name = "TRANSIENT_SQL_PATH_GUARD"; Operation = {
      Assert-DisposableWorkerSqlPath -SqlFile ([string]$CreationState.Path) -RunDirectory $RunDirectory
    } },
    [pscustomobject]@{ Name = "TRANSIENT_SQL_PATH_REMOVE"; Operation = {
      Assert-DisposableWorkerSqlPath -SqlFile ([string]$CreationState.Path) -RunDirectory $RunDirectory
      if ($script:TransientSqlFixtureFault -ceq "removal_failure") {
        Throw-StableFailure -Code "transient_sql_fixture_removal_failure" -FailureClass "postcondition_rejection"
      }
      if (Test-Path -LiteralPath $CreationState.Path) {
        Assert-Condition -Condition (Test-Path -LiteralPath $CreationState.Path -PathType Leaf) `
          -Code "transient_sql_cleanup_nonfile_rejected" -FailureClass "postcondition_rejection"
        Remove-Item -LiteralPath $CreationState.Path -Force
      }
    } },
    [pscustomobject]@{ Name = "TRANSIENT_SQL_PATH_ABSENT"; Operation = {
      Assert-DisposableWorkerSqlPath -SqlFile ([string]$CreationState.Path) -RunDirectory $RunDirectory
      Assert-Condition -Condition (-not (Test-Path -LiteralPath $CreationState.Path)) `
        -Code "transient_sql_cleanup_absence_rejected" -FailureClass "postcondition_rejection"
    } }
  )
  $CreationState.SecondaryCleanupErrors = @($cleanup.SecondaryErrors)
  $CreationState.RemovalSucceeded = [bool]($cleanup.Succeeded -and -not (Test-Path -LiteralPath $CreationState.Path))
  return $cleanup
}

function Assert-TransientSqlFileVerified {
  param(
    [Parameter(Mandatory = $true)][object]$CreationState,
    [Parameter(Mandatory = $true)][string]$RunDirectory
  )
  Assert-DisposableWorkerSqlPath -SqlFile ([string]$CreationState.Path) -RunDirectory $RunDirectory
  Assert-Condition -Condition (Test-Path -LiteralPath $CreationState.Path -PathType Leaf) `
    -Code "transient_sql_file_missing" -FailureClass "source_integrity_rejection"
  $item = Get-Item -LiteralPath $CreationState.Path -Force
  Assert-Condition -Condition (-not $item.PSIsContainer -and $item.Length -gt 0) `
    -Code "transient_sql_file_shape_rejected" -FailureClass "source_integrity_rejection"
  $actualBytes = [System.IO.File]::ReadAllBytes($CreationState.Path)
  $hasBom = $actualBytes.Length -ge 3 -and $actualBytes[0] -eq 0xEF -and $actualBytes[1] -eq 0xBB -and $actualBytes[2] -eq 0xBF
  Assert-Condition -Condition (-not $hasBom) -Code "transient_sql_bom_rejected" -FailureClass "source_integrity_rejection"
  $strictUtf8 = New-Object System.Text.UTF8Encoding($false, $true)
  $actualContent = $strictUtf8.GetString($actualBytes)
  $expectedBytes = (New-Object System.Text.UTF8Encoding($false)).GetBytes([string]$CreationState.CanonicalContent)
  Assert-Condition -Condition ($actualContent -ceq [string]$CreationState.CanonicalContent) `
    -Code "transient_sql_content_rejected" -FailureClass "source_integrity_rejection"
  Assert-Condition -Condition ([Convert]::ToBase64String($actualBytes) -ceq [Convert]::ToBase64String($expectedBytes)) `
    -Code "transient_sql_bytes_rejected" -FailureClass "source_integrity_rejection"
  $actualSha256 = Get-Sha256 -Path $CreationState.Path
  Assert-Condition -Condition ($actualSha256 -ceq [string]$CreationState.ExpectedSha256) `
    -Code "transient_sql_sha256_rejected" -FailureClass "source_integrity_rejection"
  $CreationState.ActualSha256 = $actualSha256
  $CreationState.ActualByteLength = [long]$actualBytes.Length
  $CreationState.Verified = $true
}

function Invoke-TransientSqlFixtureExclusiveWrite {
  param(
    [Parameter(Mandatory = $true)][string]$FullPath,
    [Parameter(Mandatory = $true)][string]$Content,
    [Parameter(Mandatory = $true)][ValidateSet("precreated_partial", "writer_construction", "write", "flush", "disposal", "removal_failure")][string]$Fault
  )
  Assert-Condition -Condition $ValidateOnly -Code "transient_sql_fixture_mode_rejected" -FailureClass "source_integrity_rejection"
  $fixtureRoot = [System.IO.Path]::GetFullPath((Split-Path -Parent $FullPath))
  Assert-Condition -Condition ((Split-Path -Leaf $fixtureRoot) -cmatch '^validate-db22-[a-f0-9]{32}$') `
    -Code "transient_sql_fixture_directory_rejected" -FailureClass "source_integrity_rejection"
  $encoding = New-Object System.Text.UTF8Encoding($false)
  $fileState = [pscustomobject]@{
    Stream = $null; Writer = $null; StreamOwned = $false; WriterOwned = $false
    WriterDisposed = $false; StreamDisposed = $false
  }
  $writeError = $null
  $writeScenario = $null
  try {
    if ($Fault -in @("precreated_partial", "removal_failure")) {
      [System.IO.File]::WriteAllBytes($FullPath, $encoding.GetBytes("partial"))
      Throw-StableFailure -Code "transient_sql_fixture_open_failure" -FailureClass "source_integrity_rejection"
    }
    $fileState.Stream = New-Object System.IO.FileStream($FullPath, [System.IO.FileMode]::CreateNew, [System.IO.FileAccess]::Write, [System.IO.FileShare]::None)
    $fileState.StreamOwned = $true
    if ($Fault -ceq "writer_construction") {
      Throw-StableFailure -Code "transient_sql_fixture_writer_construction_failure" -FailureClass "source_integrity_rejection"
    }
    $fileState.Writer = New-Object System.IO.StreamWriter($fileState.Stream, $encoding)
    $fileState.WriterOwned = $true
    if ($Fault -ceq "write") {
      $fileState.Writer.Write("partial")
      Throw-StableFailure -Code "transient_sql_fixture_write_failure" -FailureClass "source_integrity_rejection"
    }
    if ($Fault -ceq "flush") {
      $fileState.Writer.Write("partial")
      $fileState.Writer.Flush()
      Throw-StableFailure -Code "transient_sql_fixture_flush_failure" -FailureClass "source_integrity_rejection"
    }
    $fileState.Writer.Write($Content)
    $fileState.Writer.Flush()
    if ($Fault -ceq "disposal") {
      $writerProxy = [pscustomobject]@{ Inner = $fileState.Writer; Events = $script:TransientSqlFixtureEvents }
      $writerProxy | Add-Member -MemberType ScriptMethod -Name Dispose -Value {
        [void]$this.Events.Add("writer_dispose_attempted")
        $this.Inner.Dispose()
        throw "transient_sql_fixture_writer_disposal_failure"
      }
      $streamProxy = [pscustomobject]@{ Inner = $fileState.Stream; Events = $script:TransientSqlFixtureEvents }
      $streamProxy | Add-Member -MemberType ScriptMethod -Name Dispose -Value {
        [void]$this.Events.Add("stream_dispose_attempted")
        $this.Inner.Dispose()
        throw "transient_sql_fixture_stream_disposal_failure"
      }
      $fileState.Writer = $writerProxy
      $fileState.Stream = $streamProxy
    }
  }
  catch {
    $writeError = $_
    $writeScenario = [string]$script:CurrentScenario
  }
  $writeCleanup = Invoke-ExternalFileStateCleanup -FileState $fileState
  Complete-OrchestrationCleanup -PrimaryError $writeError -PrimaryScenario $writeScenario -CleanupResult $writeCleanup `
    -CleanupFailureCode "external_file_cleanup_rejected"
  Assert-Condition -Condition ($null -eq $fileState.Writer -and $null -eq $fileState.Stream -and
    (-not $fileState.WriterOwned -or $fileState.WriterDisposed) -and
    (-not $fileState.StreamOwned -or $fileState.StreamDisposed) -and
    (Test-Path -LiteralPath $FullPath -PathType Leaf)) -Code "transient_sql_fixture_write_postcondition_rejected"
}

function New-SqlFile {
  param(
    [Parameter(Mandatory = $true)][string]$RunDirectory,
    [Parameter(Mandatory = $true)][string]$Label,
    [Parameter(Mandatory = $true)][string]$Sql,
    [Parameter(Mandatory = $true)][ValidateSet("caller", "controller")][string]$InitialOwner
  )
  Assert-Condition -Condition (Test-Path -LiteralPath $RunDirectory -PathType Container) -Code "sql_run_directory_rejected"
  Assert-Condition -Condition ($Label -cmatch '^[a-z0-9_]+$') -Code "sql_label_rejected"
  $path = [System.IO.Path]::GetFullPath((Join-Path $RunDirectory ("worker_" + $Label + "_" + [guid]::NewGuid().ToString("N") + ".sql")))
  Assert-DisposableWorkerSqlPath -SqlFile $path -RunDirectory $RunDirectory
  $canonicalContent = $Sql.Trim() + "`n"
  $canonicalRunDirectory = [System.IO.Path]::GetFullPath($RunDirectory).TrimEnd('\', '/')
  $canonicalFileName = Split-Path -Leaf $path
  $canonicalBytes = (New-Object System.Text.UTF8Encoding($false)).GetBytes($canonicalContent)
  $creationState = [pscustomobject]@{
    Path = $path
    CanonicalPath = $path
    CanonicalRunDirectory = $canonicalRunDirectory
    CanonicalFileName = $canonicalFileName
    CanonicalContent = $canonicalContent
    ExpectedSha256 = Get-TextSha256 -Text $canonicalContent
    ExpectedByteLength = [long]$canonicalBytes.Length
    WriteCompleted = $false
    Verified = $false
    ActualSha256 = $null
    ActualByteLength = $null
    RemovalAttempted = $false
    RemovalSucceeded = $false
    SecondaryCleanupErrors = @()
  }
  $creationError = $null
  $creationScenario = $null
  try {
    if ($script:TransientSqlFixtureFault -in @("precreated_partial", "writer_construction", "write", "flush", "disposal", "removal_failure")) {
      Invoke-TransientSqlFixtureExclusiveWrite -FullPath $creationState.Path -Content $creationState.CanonicalContent `
        -Fault ([string]$script:TransientSqlFixtureFault)
    }
    else {
      Write-ExternalUtf8File -Path $creationState.Path -Content $creationState.CanonicalContent -Exclusive
    }
    $creationState.WriteCompleted = $true
    if ($script:TransientSqlFixtureFault -ceq "content_mismatch") {
      [System.IO.File]::WriteAllText($creationState.Path, "mismatch`n", (New-Object System.Text.UTF8Encoding($false)))
    }
    if ($script:TransientSqlFixtureFault -ceq "hash_mismatch") {
      $creationState.ExpectedSha256 = ("0" * 64)
    }
    Assert-TransientSqlFileVerified -CreationState $creationState -RunDirectory $RunDirectory
  }
  catch {
    $creationError = $_
    $creationScenario = [string]$script:CurrentScenario
  }
  if ($null -ne $creationError) {
    $cleanup = Invoke-TransientSqlPathCleanup -CreationState $creationState -RunDirectory $RunDirectory
    Complete-OrchestrationCleanup -PrimaryError $creationError -PrimaryScenario $creationScenario -CleanupResult $cleanup `
      -CleanupFailureCode "transient_sql_cleanup_rejected"
  }
  Assert-Condition -Condition ($creationState.WriteCompleted -and $creationState.Verified -and
    $creationState.ActualSha256 -ceq $creationState.ExpectedSha256 -and
    [long]$creationState.ActualByteLength -eq [long]$creationState.ExpectedByteLength -and
    -not $creationState.RemovalAttempted -and (Test-Path -LiteralPath $creationState.Path -PathType Leaf)) `
    -Code "transient_sql_return_before_verification_rejected" -FailureClass "source_integrity_rejection"
  $artifact = New-PsqlVerifiedTransientArtifact -CreationState $creationState -InitialOwner $InitialOwner
  if ($ValidateOnly -and (Split-Path -Leaf ([System.IO.Path]::GetFullPath($RunDirectory))) -cmatch '^validate-db23-[a-f0-9]{32}$') {
    $script:Db23LastCreatedSqlFile = $artifact.Path
    $script:Db23LastHandoffState = $artifact.OwnershipState
  }
  if ($ValidateOnly -and (Split-Path -Leaf ([System.IO.Path]::GetFullPath($RunDirectory))) -cmatch '^validate-db24-[a-f0-9]{32}$') {
    $script:Db24LastCreatedSqlFile = $artifact.Path
    $script:Db24LastHandoffState = $artifact.OwnershipState
  }
  if ($ValidateOnly -and (Split-Path -Leaf ([System.IO.Path]::GetFullPath($RunDirectory))) -cmatch '^validate-db25-[a-f0-9]{32}$') {
    $script:Db25LastCreatedArtifact = $artifact
  }
  return $artifact
}

function New-PairedTransientSqlOwnershipState {
  return [pscustomobject]@{
    HolderSqlFile = $null
    WaiterSqlFile = $null
    HolderWorker = $null
    WaiterWorker = $null
    HolderOwnershipState = $null
    WaiterOwnershipState = $null
    HolderSqlOwnedByWorker = $false
    WaiterSqlOwnedByWorker = $false
  }
}

function Set-TransientSqlWorkerOwnership {
  param(
    [Parameter(Mandatory = $true)][object]$State,
    [Parameter(Mandatory = $true)][ValidateSet("Holder", "Waiter")][string]$Role,
    [AllowNull()][object]$Worker,
    [Parameter(Mandatory = $true)][bool]$OwnedByWorker
  )
  $fileProperty = $Role + "SqlFile"
  $workerProperty = $Role + "Worker"
  $ownershipProperty = $Role + "SqlOwnedByWorker"
  $stateProperty = $Role + "OwnershipState"
  Assert-Condition -Condition (Test-ObjectProperty -Value $State -Name $fileProperty) -Code "transient_sql_state_shape_rejected"
  if ($OwnedByWorker) {
    Assert-Condition -Condition ($null -ne $Worker -and -not [string]::IsNullOrWhiteSpace([string]$State.$fileProperty) -and
      $null -ne $State.$stateProperty -and [string]$State.$stateProperty.OwnerState -ceq "worker") `
      -Code "transient_sql_worker_ownership_rejected"
  }
  $State.$workerProperty = $Worker
  $State.$ownershipProperty = $OwnedByWorker
}

function Remove-UnownedTransientSqlFile {
  param(
    [Parameter(Mandatory = $true)][object]$State,
    [Parameter(Mandatory = $true)][ValidateSet("Holder", "Waiter")][string]$Role,
    [Parameter(Mandatory = $true)][string]$RunDirectory
  )
  $fileProperty = $Role + "SqlFile"
  $workerProperty = $Role + "Worker"
  $ownershipProperty = $Role + "SqlOwnedByWorker"
  $stateProperty = $Role + "OwnershipState"
  $sqlFile = [string]$State.$fileProperty
  if ([string]::IsNullOrWhiteSpace($sqlFile)) { return }
  $worker = $State.$workerProperty
  $ownedByWorker = [bool]$State.$ownershipProperty
  $ownershipState = $State.$stateProperty
  if ($null -ne $ownershipState -and [string]$ownershipState.OwnerState -cin @("starter", "worker")) {
    return
  }
  if ($null -ne $ownershipState -and [string]$ownershipState.OwnerState -cin @("caller", "controller")) {
    $cleanup = Invoke-PsqlDisposableControllerCleanup -State $ownershipState
    Assert-Condition -Condition $cleanup.Succeeded -Code "paired_transient_sql_cleanup_rejected" -FailureClass "postcondition_rejection"
  }
  elseif ($null -ne $ownershipState -and [string]$ownershipState.OwnerState -ceq "completed") {
    Assert-Condition -Condition (-not (Test-Path -LiteralPath $ownershipState.CanonicalPath)) `
      -Code "paired_transient_completed_path_reappeared" -FailureClass "postcondition_rejection"
  }
  elseif ($null -eq $ownershipState) {
    Assert-Condition -Condition $false -Code "paired_transient_sql_owner_missing" -FailureClass "postcondition_rejection"
  }
  $State.$fileProperty = $null
  $State.$ownershipProperty = $false
  $State.$stateProperty = $ownershipState
}

function Get-TransientWorkerSqlFileCount {
  param([Parameter(Mandatory = $true)][string]$RunDirectory)
  if (-not (Test-Path -LiteralPath $RunDirectory -PathType Container)) { return 0 }
  $files = @(Get-ChildItem -LiteralPath $RunDirectory -Filter "worker_*.sql" -File -ErrorAction Stop)
  foreach ($file in $files) {
    Assert-DisposableWorkerSqlPath -SqlFile $file.FullName -RunDirectory $RunDirectory
  }
  return [int]$files.Count
}

function Assert-DisposableWorkerSqlPath {
  param(
    [Parameter(Mandatory = $true)][string]$SqlFile,
    [Parameter(Mandatory = $true)][string]$RunDirectory
  )
  $full = [System.IO.Path]::GetFullPath($SqlFile)
  $canonicalRunDirectory = [System.IO.Path]::GetFullPath($RunDirectory).TrimEnd('\', '/')
  $canonicalParent = [System.IO.Path]::GetFullPath((Split-Path -Parent $full)).TrimEnd('\', '/')
  $canonicalFileName = Split-Path -Leaf $full
  $repositoryRoot = [System.IO.Path]::GetFullPath($script:RepositoryRoot).TrimEnd('\', '/') + [System.IO.Path]::DirectorySeparatorChar
  Assert-Condition -Condition (-not ($full + [System.IO.Path]::DirectorySeparatorChar).StartsWith($repositoryRoot, [System.StringComparison]::OrdinalIgnoreCase)) `
    -Code "worker_sql_delete_repository_rejected"
  foreach ($protected in @($script:MigrationPath, $script:PreflightPath, $script:VerifierPath, $script:RollbackPath)) {
    Assert-Condition -Condition (-not [string]::Equals($full, [System.IO.Path]::GetFullPath($protected), [System.StringComparison]::OrdinalIgnoreCase)) `
      -Code "worker_sql_delete_protected_artifact_rejected"
  }
  Assert-Condition -Condition ([string]::Equals($canonicalParent, $canonicalRunDirectory, [System.StringComparison]::OrdinalIgnoreCase)) `
    -Code "worker_sql_delete_outside_run_root"
  Assert-Condition -Condition ($canonicalFileName -cmatch '^worker_[a-z0-9_]+_[0-9a-f]{32}\.sql$') `
    -Code "worker_sql_delete_filename_rejected" -FailureClass "source_integrity_rejection"
  Assert-Condition -Condition (-not $canonicalFileName.Contains(':')) -Code "worker_sql_delete_alternate_stream_rejected" `
    -FailureClass "source_integrity_rejection"
  if (Test-Path -LiteralPath $full) {
    $item = Get-Item -LiteralPath $full -Force -ErrorAction Stop
    Assert-Condition -Condition (-not $item.PSIsContainer) -Code "worker_sql_delete_nonfile_rejected" -FailureClass "source_integrity_rejection"
    $reparsePoint = [System.IO.FileAttributes]::ReparsePoint
    Assert-Condition -Condition (($item.Attributes -band $reparsePoint) -eq 0) `
      -Code "worker_sql_delete_reparse_point_rejected" -FailureClass "source_integrity_rejection"
  }
}

function Remove-DisposableWorkerSqlFile {
  param([Parameter(Mandatory = $true)][object]$Worker)
  if ($Worker.DeleteSqlFileOnCompletion -ne $true) {
    return
  }
  Assert-Condition -Condition ((Test-ObjectProperty -Value $Worker -Name "DisposableSqlOwnershipState") -and
    $null -ne $Worker.DisposableSqlOwnershipState) -Code "worker_sql_ownership_state_missing" -FailureClass "postcondition_rejection"
  $ownershipState = $Worker.DisposableSqlOwnershipState
  Assert-PsqlDisposableOwnershipInvariant -State $ownershipState
  Assert-Condition -Condition ([string]$ownershipState.OwnerState -ceq "worker" -and $Worker.Process.HasExited) `
    -Code "worker_sql_remove_before_exit_rejected" -FailureClass "postcondition_rejection"
  $ownershipState.ProcessTerminationObserved = $true
  [void](Assert-PsqlDisposableFrozenIdentity -State $ownershipState)
  if (Test-Path -LiteralPath $ownershipState.CanonicalPath -PathType Leaf) {
    $ownershipState.RemovalAttemptCount = [int]$ownershipState.RemovalAttemptCount + 1
    Remove-Item -LiteralPath $ownershipState.CanonicalPath -Force
  }
}

function Invoke-PsqlWorkerStartFailureCleanup {
  param(
    [Parameter(Mandatory = $true)][object]$State,
    [Parameter(Mandatory = $true)][string]$ApplicationName,
    [Parameter(Mandatory = $true)][string]$RunDirectory,
    [AllowNull()][object]$WorkerExecutionContext,
    [Parameter(Mandatory = $true)][bool]$DeleteSqlFileOnCompletion,
    [AllowNull()][object]$FallbackProcess = $null,
    [bool]$FallbackProcessStarted = $false,
    [AllowNull()][System.Diagnostics.ProcessStartInfo]$FallbackStartInfo = $null
  )
  $cleanupProcess = if ($null -ne $State.Process) { $State.Process } else { $FallbackProcess }
  $cleanupProcessStarted = [bool]($State.ProcessStartObserved -or $FallbackProcessStarted)
  $cleanupStartInfo = if ($null -ne $State.StartInfo) { $State.StartInfo } else { $FallbackStartInfo }
  $stateHasDisposableOwner = Test-ObjectProperty -Value $State -Name "OwnerState"
  $workerOwnership = [pscustomobject]@{ Category = if ($stateHasDisposableOwner -and [string]$State.OwnerState -ceq "worker") {
    "invalid_partial_worker"
  }
  elseif ($stateHasDisposableOwner) { [string]$State.OwnerState } else { "protected_process" } }
  $cleanup = Invoke-OrchestrationCleanup -EmitFailureMarkers -CleanupOperations @(
    [pscustomobject]@{ Name = "PSQL_START_WORKER_OWNERSHIP_INTEGRITY"; Operation = {
      if ($stateHasDisposableOwner -and [string]$State.OwnerState -ceq "worker") {
        try {
          Assert-PsqlDisposableOwnershipInvariant -State $State
          Assert-Condition -Condition ($null -ne $State.Worker -and $null -ne $State.Process -and
            [object]::ReferenceEquals($State.Worker.Process, $State.Process) -and
            [object]::ReferenceEquals($State.Worker.DisposableSqlOwnershipState, $State)) `
            -Code "worker_owned_start_state_incomplete" -FailureClass "postcondition_rejection"
          $workerOwnership.Category = "complete_worker"
        }
        catch {
          $workerOwnership.Category = "invalid_partial_worker"
          Throw-StableFailure -Code "worker_owned_start_state_incomplete" -FailureClass "postcondition_rejection"
        }
      }
    } },
    [pscustomobject]@{ Name = "PSQL_START_INFO_CLEAR"; Operation = {
      if ($null -ne $cleanupStartInfo -and -not $State.StartInfoMaterialCleared) {
        Clear-PsqlStartInfoMaterial -State $State -StartInfo $cleanupStartInfo
      }
    } },
    [pscustomobject]@{ Name = "PSQL_START_FALLBACK_ESCROW"; Operation = {
      if ($cleanupProcessStarted -and $null -ne $cleanupProcess -and $null -eq $State.Process) {
        $State.Process = $cleanupProcess
        $State.ProcessStartObserved = $true
        if ($DeleteSqlFileOnCompletion -and [string]$State.OwnerState -ceq "controller") {
          $State.OwnerState = "starter"
        }
      }
    } },
    [pscustomobject]@{ Name = "PSQL_START_INPUT_CLOSE"; Operation = {
      if ($cleanupProcessStarted -and $null -ne $cleanupProcess -and -not $cleanupProcess.HasExited -and
        $null -ne $cleanupStartInfo -and $cleanupStartInfo.RedirectStandardInput) {
        $cleanupProcess.StandardInput.Close()
      }
    } },
    [pscustomobject]@{ Name = "PSQL_START_PROCESS_TERMINATE"; Operation = {
      if ($cleanupProcessStarted -and $null -ne $cleanupProcess) {
        if (-not $cleanupProcess.HasExited) {
          $cleanupProcess.Kill()
          [void]$cleanupProcess.WaitForExit(5000)
        }
        Assert-Condition -Condition $cleanupProcess.HasExited -Code "worker_termination_not_observed"
        $State.ProcessTerminationObserved = $true
      }
    } },
    [pscustomobject]@{ Name = "PSQL_START_LOCAL_PID_REMOVE"; Operation = {
      if ($State.LocalPidAddAttempted) {
        $State.LocalPidRemovalAttempted = $true
        Assert-Condition -Condition ($State.ProcessTerminationObserved -and $cleanupProcess.HasExited) `
          -Code "worker_pid_removed_before_exit" -FailureClass "postcondition_rejection"
        if ((Test-ObjectProperty -Value $State -Name "FixturePidOperationsOnly") -and $State.FixturePidOperationsOnly) {
          $State.FixtureLocalPidRemovalCount = [int]$State.FixtureLocalPidRemovalCount + 1
        }
        else {
          Update-WorkerPidManifest -RunDirectory $RunDirectory -ProcessId $State.ProcessId -ApplicationName $ApplicationName -Operation "remove"
        }
        $State.LocalPidRecorded = $false
      }
    } },
    [pscustomobject]@{ Name = "PSQL_START_EXECUTE_PID_REMOVE"; Operation = {
      if ($State.ExecutePidAddAttempted) {
        $State.ExecutePidRemovalAttempted = $true
        Assert-Condition -Condition ($State.ProcessTerminationObserved -and $cleanupProcess.HasExited) `
          -Code "worker_pid_removed_before_exit" -FailureClass "postcondition_rejection"
        if ((Test-ObjectProperty -Value $State -Name "FixturePidOperationsOnly") -and $State.FixturePidOperationsOnly) {
          $State.FixtureExecutePidRemovalCount = [int]$State.FixtureExecutePidRemovalCount + 1
        }
        else {
          Update-ExecuteWorkerManifest -ExecutionContext $WorkerExecutionContext -ProcessId $State.ProcessId -Operation "remove"
        }
        $State.ExecutePidRecorded = $false
      }
    } },
    [pscustomobject]@{ Name = "PSQL_START_DISPOSABLE_SQL_REMOVE"; Operation = {
      if ($DeleteSqlFileOnCompletion -and [string]$State.OwnerState -ceq "starter") {
        Assert-Condition -Condition ($State.ProcessTerminationObserved -and $cleanupProcess.HasExited) `
          -Code "worker_sql_remove_before_exit_rejected" -FailureClass "postcondition_rejection"
        $sqlCleanup = Invoke-PsqlDisposableStarterCleanup -State $State
        Assert-Condition -Condition $sqlCleanup.Succeeded -Code "worker_start_sql_cleanup_rejected" -FailureClass "postcondition_rejection"
      }
      elseif ($DeleteSqlFileOnCompletion -and $workerOwnership.Category -ceq "complete_worker") {
        Assert-Condition -Condition ($State.ProcessTerminationObserved -and $cleanupProcess.HasExited) `
          -Code "worker_sql_remove_before_exit_rejected" -FailureClass "postcondition_rejection"
        Remove-DisposableWorkerSqlFile -Worker $State.Worker
        Complete-PsqlDisposableWorkerOwnership -State $State
      }
      elseif ($DeleteSqlFileOnCompletion -and $workerOwnership.Category -ceq "invalid_partial_worker") {
        Throw-StableFailure -Code "worker_owned_start_state_incomplete" -FailureClass "postcondition_rejection"
      }
    } }
  )
  $State.SecondaryCleanupErrors = @($State.SecondaryCleanupErrors) + @($cleanup.SecondaryErrors)
  return $cleanup
}

function New-PsqlProcessStartState {
  param(
    [Parameter(Mandatory = $true)][System.Diagnostics.ProcessStartInfo]$StartInfo,
    [Parameter(Mandatory = $true)][string]$RunDirectory,
    [Parameter(Mandatory = $true)][string]$ApplicationName,
    [AllowNull()][object]$WorkerExecutionContext
  )
  return [pscustomobject]@{
    Process = $null; ProcessStartObserved = $false; ProcessTerminationObserved = $false
    ProcessId = $null; ProcessIdObserved = $false; Worker = $null; StartInfo = $StartInfo
    StartInfoMaterialClearAttempted = $false; StartInfoMaterialCleared = $false
    LocalPidAddAttempted = $false; LocalPidRecorded = $false; LocalPidRemovalAttempted = $false
    ExecutePidAddAttempted = $false; ExecutePidRecorded = $false; ExecutePidRemovalAttempted = $false
    SecondaryCleanupErrors = @(); PrimaryErrorRecord = $null; PrimaryFailureClass = $null; PrimaryScenario = $null
    RunDirectory = $RunDirectory; ApplicationName = $ApplicationName; ExecutionContext = $WorkerExecutionContext
  }
}

function Get-PsqlProcessId {
  param([Parameter(Mandatory = $true)][object]$Process)
  if ($ValidateOnly -and (Test-ObjectProperty -Value $Process -Name "FixtureProcessIdReadFails") -and
    $Process.FixtureProcessIdReadFails) {
    Throw-StableFailure -Code "db25_synthetic_process_id_failure" -FailureClass "worker_crash"
  }
  return [int]$Process.Id
}

function Start-PsqlWorker {
  param(
    [Parameter(Mandatory = $true)][object]$Connection,
    [Parameter(Mandatory = $true)][string]$PsqlPath,
    [Parameter(Mandatory = $true)][string]$SqlFile,
    [Parameter(Mandatory = $true)][string]$ApplicationName,
    [Parameter(Mandatory = $true)][string]$RunDirectory,
    [ValidateSet("read committed", "repeatable read")][string]$DefaultIsolation = "read committed",
    [int]$StatementTimeoutMilliseconds = 90000,
    [int]$LockTimeoutMilliseconds = 30000,
    [bool]$DeleteSqlFileOnCompletion = $false,
    [AllowNull()][object]$DisposableSqlOwnershipState = $null,
    [switch]$EmitSessionIsolationMarker,
    [switch]$EmitRepositoryFileCompletedMarker
  )
  if ($ValidateOnly) {
    $fixtureLeaf = Split-Path -Leaf ([System.IO.Path]::GetFullPath($RunDirectory))
    if ($fixtureLeaf -cmatch '^validate-db23-[a-f0-9]{32}$') { $script:Db23FixtureStartAttemptCount++ }
    if ($fixtureLeaf -cmatch '^validate-db24-[a-f0-9]{32}$') { $script:Db24FixtureStartAttemptCount++ }
    if ($fixtureLeaf -cmatch '^validate-db25-[a-f0-9]{32}$') { $script:Db25FixtureStartAttemptCount++ }
    if ($fixtureLeaf -cmatch '^validate-db26-[a-f0-9]{32}$') { $script:Db26FixtureStartAttemptCount++ }
  }
  if ($DeleteSqlFileOnCompletion) {
    Assert-Condition -Condition ($null -ne $DisposableSqlOwnershipState) `
      -Code "worker_sql_ownership_state_missing" -FailureClass "source_integrity_rejection"
    [void](Assert-DisposableWorkerSqlPath -SqlFile $SqlFile -RunDirectory $RunDirectory)
    Assert-PsqlDisposableOwnershipInvariant -State $DisposableSqlOwnershipState
    Assert-Condition -Condition ([string]$DisposableSqlOwnershipState.OwnerState -ceq "controller") `
      -Code "worker_sql_controller_ownership_missing" -FailureClass "source_integrity_rejection"
    Assert-PsqlDisposableStarterPreconditions -State $DisposableSqlOwnershipState
  }
  $startInfo = New-PsqlStartInfo -PsqlPath $PsqlPath -Connection $Connection -SqlFile $SqlFile -ApplicationName $ApplicationName -StatementTimeoutMilliseconds $StatementTimeoutMilliseconds -LockTimeoutMilliseconds $LockTimeoutMilliseconds -DefaultIsolation $DefaultIsolation -EmitSessionIsolationMarker:$EmitSessionIsolationMarker -EmitRepositoryFileCompletedMarker:$EmitRepositoryFileCompletedMarker
  $executionContext = if (Test-ObjectProperty -Value $Connection -Name "ExecutionContext") { $Connection.ExecutionContext } else { $null }
  $startState = if ($DeleteSqlFileOnCompletion) { $DisposableSqlOwnershipState } else {
    New-PsqlProcessStartState -StartInfo $startInfo -RunDirectory $RunDirectory -ApplicationName $ApplicationName -WorkerExecutionContext $executionContext
  }
  $startState.StartInfo = $startInfo
  $process = New-Object System.Diagnostics.Process
  $process.StartInfo = $startInfo
  $processStarted = $false
  $fallbackProcess = $process
  $fallbackStartInfo = $startInfo
  try {
    Assert-Condition -Condition ($process.Start()) -Code "worker_start_rejected"
    $processStarted = $true
    if ($DeleteSqlFileOnCompletion) {
      $startState.Process = $process
      $startState.ProcessStartObserved = $true
      $startState.OwnerState = "starter"
    }
    else {
      $startState.Process = $process
      $startState.ProcessStartObserved = $true
    }
    $processId = Get-PsqlProcessId -Process $process
    $startState.ProcessId = $processId
    $startState.ProcessIdObserved = $true
    Clear-PsqlStartInfoMaterial -State $startState -StartInfo $startInfo
    $stdoutTask = $process.StandardOutput.ReadToEndAsync()
    $stderrTask = $process.StandardError.ReadToEndAsync()
    $startState.LocalPidAddAttempted = $true
    Update-WorkerPidManifest -RunDirectory $RunDirectory -ProcessId $processId -ApplicationName $ApplicationName -Operation "add"
    $startState.LocalPidRecorded = $true
    $startState.ExecutePidAddAttempted = $true
    Update-ExecuteWorkerManifest -ExecutionContext $executionContext -ProcessId $processId -Operation "add"
    $startState.ExecutePidRecorded = $true
    $worker = [pscustomobject]@{
      Process = $process
      StdoutTask = $stdoutTask
      StderrTask = $stderrTask
      SqlFile = $SqlFile
      ApplicationName = $ApplicationName
      RunDirectory = $RunDirectory
      DeleteSqlFileOnCompletion = $DeleteSqlFileOnCompletion
      ProcessStartState = $startState
      DisposableSqlOwnershipState = $DisposableSqlOwnershipState
      ExecutionContext = $executionContext
      StartedAt = [DateTime]::UtcNow
    }
    Assert-Condition -Condition ($startState.StartInfoMaterialClearAttempted -and $startState.StartInfoMaterialCleared -and
      -not (Test-PsqlStartInfoContainsPgMaterial -StartInfo $startInfo)) `
      -Code "worker_start_info_material_retained" -FailureClass "postcondition_rejection"
    Assert-Condition -Condition ($startState.ProcessStartObserved -and $startState.ProcessIdObserved -and
      [int]$startState.ProcessId -eq [int]$processId -and $startState.LocalPidAddAttempted -and
      $startState.LocalPidRecorded -and $startState.ExecutePidAddAttempted -and $startState.ExecutePidRecorded) `
      -Code "worker_pid_registration_incomplete" -FailureClass "postcondition_rejection"
    if ($DeleteSqlFileOnCompletion) {
      [void](Assert-PsqlDisposableFrozenIdentity -State $startState)
      Assert-Condition -Condition ([object]::ReferenceEquals($worker.Process, $startState.Process) -and
        [object]::ReferenceEquals($worker.DisposableSqlOwnershipState, $startState) -and
        [string]::Equals([System.IO.Path]::GetFullPath([string]$worker.SqlFile), [string]$startState.CanonicalPath, [System.StringComparison]::OrdinalIgnoreCase) -and
        [string]::Equals([System.IO.Path]::GetFullPath([string]$worker.RunDirectory).TrimEnd('\', '/'), [string]$startState.CanonicalRunDirectory, [System.StringComparison]::OrdinalIgnoreCase)) `
        -Code "worker_candidate_incomplete" -FailureClass "postcondition_rejection"
      Set-PsqlDisposableWorkerOwnership -State $startState -Worker $worker
      return $worker
    }
    return $worker
  }
  catch {
    $workerStartError = $_
    if ($null -eq $startState.PrimaryErrorRecord) {
      $startState.PrimaryErrorRecord = $workerStartError
      $startState.PrimaryFailureClass = [string]$workerStartError.Exception.Data["FailureClass"]
      $startState.PrimaryScenario = [string]$script:CurrentScenario
    }
    $startCleanup = Invoke-PsqlWorkerStartFailureCleanup -State $startState -ApplicationName $ApplicationName `
      -RunDirectory $RunDirectory -WorkerExecutionContext $executionContext -DeleteSqlFileOnCompletion $DeleteSqlFileOnCompletion `
      -FallbackProcess $fallbackProcess -FallbackProcessStarted $processStarted -FallbackStartInfo $fallbackStartInfo
    Complete-OrchestrationCleanup -PrimaryError $workerStartError -PrimaryScenario ([string]$script:CurrentScenario) `
      -CleanupResult $startCleanup -CleanupFailureCode "worker_start_cleanup_rejected"
  }
}

function Wait-PsqlWorker {
  param(
    [Parameter(Mandatory = $true)][object]$Worker,
    [int]$TimeoutMilliseconds = $script:WorkerTimeoutMilliseconds,
    [switch]$KeepRawLogs
  )
  $timedOut = -not $Worker.Process.WaitForExit($TimeoutMilliseconds)
  if ($timedOut) {
    try { $Worker.Process.Kill() } catch { }
    [void]$Worker.Process.WaitForExit(5000)
  }
  Assert-Condition -Condition $Worker.Process.HasExited -Code "worker_termination_not_observed"
  $startState = $Worker.ProcessStartState
  $startState.ProcessTerminationObserved = $true
  $stdout = $Worker.StdoutTask.Result
  $stderr = $Worker.StderrTask.Result
  $exitCode = if ($timedOut) { -1 } else { $Worker.Process.ExitCode }
  $elapsed = [int]([DateTime]::UtcNow - $Worker.StartedAt).TotalMilliseconds
  $completedAt = [DateTime]::UtcNow
  $startState.LocalPidRemovalAttempted = $true
  Update-WorkerPidManifest -RunDirectory $Worker.RunDirectory -ProcessId $Worker.Process.Id -ApplicationName $Worker.ApplicationName -Operation "remove"
  $startState.LocalPidRecorded = $false
  $startState.ExecutePidRemovalAttempted = $true
  Update-ExecuteWorkerManifest -ExecutionContext $Worker.ExecutionContext -ProcessId $Worker.Process.Id -Operation "remove"
  $startState.ExecutePidRecorded = $false
  $rawBase = Join-Path $Worker.RunDirectory ("raw_" + $Worker.ApplicationName)
  $stdoutPath = $rawBase + ".stdout.local.txt"
  $stderrPath = $rawBase + ".stderr.local.txt"
  Write-ExternalUtf8File -Path $stdoutPath -Content $stdout
  Write-ExternalUtf8File -Path $stderrPath -Content $stderr
  if (-not $KeepRawLogs) {
    Remove-Item -LiteralPath $stdoutPath, $stderrPath -Force -ErrorAction SilentlyContinue
  }
  Remove-DisposableWorkerSqlFile -Worker $Worker
  if ($Worker.DeleteSqlFileOnCompletion) {
    Complete-PsqlDisposableWorkerOwnership -State $Worker.DisposableSqlOwnershipState
  }
  [void]$script:WorkerResults.Add([pscustomobject]@{
    ScenarioId = $script:CurrentScenario
    ExitCode = $exitCode
    TimedOut = $timedOut
    Deadlock = [bool](($stderr + "`n" + $stdout) -match '(?i)40P01|deadlock detected')
  })
  return [pscustomobject]@{
    ExitCode = $exitCode
    TimedOut = $timedOut
    Stdout = $stdout
    Stderr = $stderr
    ElapsedMilliseconds = $elapsed
    CompletedAtUtc = $completedAt
  }
}

function Stop-PsqlWorker {
  param([AllowNull()][object]$Worker)
  if ($null -eq $Worker) { return [pscustomobject]@{ Succeeded = $true; SecondaryErrors = @() } }
  $state = $Worker.ProcessStartState
  $cleanup = Invoke-PsqlWorkerStartFailureCleanup -State $state -ApplicationName $Worker.ApplicationName `
    -RunDirectory $Worker.RunDirectory -WorkerExecutionContext $Worker.ExecutionContext `
    -DeleteSqlFileOnCompletion ([bool]$Worker.DeleteSqlFileOnCompletion) -FallbackProcess $Worker.Process `
    -FallbackProcessStarted $true -FallbackStartInfo $state.StartInfo
  if ($cleanup.Succeeded -and $Worker.DeleteSqlFileOnCompletion -and [string]$state.OwnerState -ceq "worker") {
    Remove-DisposableWorkerSqlFile -Worker $Worker
    Complete-PsqlDisposableWorkerOwnership -State $state
  }
  Assert-Condition -Condition $cleanup.Succeeded -Code "worker_cleanup_rejected"
  return $cleanup
}

function Get-StagedWorkerNextState {
  param(
    [Parameter(Mandatory = $true)][string]$CurrentState,
    [Parameter(Mandatory = $true)][ValidateSet("A", "B")][string]$Stage,
    [Parameter(Mandatory = $true)][bool]$ProcessHasExited
  )
  Assert-Condition -Condition (-not $ProcessHasExited) -Code "staged_worker_already_completed" -FailureClass "worker_crash"
  if ($Stage -ceq "A") {
    Assert-Condition -Condition ($CurrentState -ceq "started") -Code "staged_worker_stage_a_rejected" -FailureClass "source_integrity_rejection"
    return "stage_a_sent"
  }
  Assert-Condition -Condition ($CurrentState -ceq "stage_a_observed") -Code "staged_worker_stage_b_rejected" -FailureClass "source_integrity_rejection"
  return "stage_b_sent"
}

function Confirm-StagedWorkerStageA {
  param(
    [Parameter(Mandatory = $true)][object]$Worker,
    [Parameter(Mandatory = $true)][bool]$ProcessHasExited
  )
  Assert-Condition -Condition (-not $ProcessHasExited -and $Worker.StageState -ceq "stage_a_sent") -Code "staged_worker_stage_a_marker_rejected" -FailureClass "worker_crash"
  $Worker.StageState = "stage_a_observed"
}

function Test-StagedWorkerPidRemovalEligible {
  param([Parameter(Mandatory = $true)][bool]$ProcessHasExited)
  return $ProcessHasExited
}

function Read-StagedPsqlWorkerStreams {
  param([Parameter(Mandatory = $true)][object]$Worker)
  foreach ($streamName in @("Stdout", "Stderr")) {
    $taskProperty = $streamName + "ReadTask"
    $linesProperty = $streamName + "Lines"
    $readerProperty = if ($streamName -eq "Stdout") { "StandardOutput" } else { "StandardError" }
    $task = $Worker.$taskProperty
    while ($null -ne $task -and $task.IsCompleted) {
      $line = $task.Result
      if ($null -eq $line) {
        $Worker.$taskProperty = $null
        break
      }
      [void]$Worker.$linesProperty.Add([string]$line)
      $reader = $Worker.Process.$readerProperty
      $task = $reader.ReadLineAsync()
      $Worker.$taskProperty = $task
    }
  }
}

function Get-MonotonicTimestamp {
  if ($ValidateOnly -and $script:Db26MonotonicFixtureActive) {
    Assert-Condition -Condition ($null -ne $script:Db26MonotonicTimestampQueue -and
      $script:Db26MonotonicTimestampQueue.Count -gt 0) -Code "db26_monotonic_fixture_exhausted" `
      -FailureClass "source_integrity_rejection"
    return [long]$script:Db26MonotonicTimestampQueue.Dequeue()
  }
  return [System.Diagnostics.Stopwatch]::GetTimestamp()
}

function Set-Db26MonotonicFixtureTimeline {
  param([Parameter(Mandatory = $true)][double[]]$ElapsedMilliseconds)
  Assert-Condition -Condition $ValidateOnly -Code "db26_monotonic_fixture_outside_validate_only" `
    -FailureClass "source_integrity_rejection"
  $queue = New-Object 'System.Collections.Generic.Queue[long]'
  foreach ($elapsed in $ElapsedMilliseconds) {
    Assert-Condition -Condition ($elapsed -ge 0) -Code "db26_monotonic_fixture_value_rejected" `
      -FailureClass "source_integrity_rejection"
    $timestamp = [long][Math]::Round($elapsed * [double][System.Diagnostics.Stopwatch]::Frequency / 1000.0)
    $queue.Enqueue($timestamp)
  }
  $script:Db26MonotonicTimestampQueue = $queue
  $script:Db26MonotonicFixtureActive = $true
}

function Clear-Db26MonotonicFixtureTimeline {
  $script:Db26MonotonicFixtureActive = $false
  $script:Db26MonotonicTimestampQueue = $null
}

function Get-MonotonicElapsedMilliseconds {
  param(
    [Parameter(Mandatory = $true)][long]$StartTimestamp,
    [Parameter(Mandatory = $true)][long]$EndTimestamp
  )
  Assert-Condition -Condition ($StartTimestamp -ge 0 -and $EndTimestamp -ge $StartTimestamp) -Code "monotonic_timestamp_rejected" -FailureClass "source_integrity_rejection"
  return ([double]($EndTimestamp - $StartTimestamp) * 1000.0 / [double][System.Diagnostics.Stopwatch]::Frequency)
}

function Assert-HardMonotonicDeadline {
  param(
    [Parameter(Mandatory = $true)][double]$ElapsedMilliseconds,
    [Parameter(Mandatory = $true)][ValidateRange(1, 600000)][int]$TimeoutMilliseconds,
    [Parameter(Mandatory = $true)][string]$FailureCode,
    [ValidateSet("unexpected_timeout", "source_integrity_rejection")][string]$FailureClass = "unexpected_timeout"
  )
  Assert-Condition -Condition ($ElapsedMilliseconds -ge 0 -and $ElapsedMilliseconds -le $TimeoutMilliseconds) -Code $FailureCode -FailureClass $FailureClass
}

function Invoke-StagedProcessStartFailureCleanup {
  param(
    [Parameter(Mandatory = $true)][object]$State,
    [Parameter(Mandatory = $true)][ValidatePattern('^[A-Z0-9_]+$')][string]$NamePrefix,
    [AllowNull()][object]$FallbackProcess = $null,
    [bool]$FallbackProcessStarted = $false,
    [AllowNull()][System.Diagnostics.ProcessStartInfo]$FallbackStartInfo = $null
  )
  $cleanupProcess = if ($null -ne $State.Process) { $State.Process } else { $FallbackProcess }
  $cleanupProcessStarted = [bool]($State.ProcessStarted -or $FallbackProcessStarted)
  $cleanupStartInfo = if ($null -ne $State.StartInfo) { $State.StartInfo } else { $FallbackStartInfo }
  return Invoke-OrchestrationCleanup -EmitFailureMarkers -CleanupOperations @(
    [pscustomobject]@{ Name = ($NamePrefix + "_START_INFO_CLEAR"); Operation = {
      if (-not $State.StartInfoMaterialCleared -and $null -ne $cleanupStartInfo) {
        Clear-PsqlStartInfoMaterial -State $State -StartInfo $cleanupStartInfo
      }
    } },
    [pscustomobject]@{ Name = ($NamePrefix + "_FALLBACK_ESCROW"); Operation = {
      if ($cleanupProcessStarted -and $null -ne $cleanupProcess -and $null -eq $State.Process) {
        $State.Process = $cleanupProcess
        $State.ProcessStarted = $true
      }
    } },
    [pscustomobject]@{ Name = ($NamePrefix + "_INPUT_CLOSE"); Operation = {
      if ($cleanupProcessStarted -and $null -ne $cleanupProcess -and -not $cleanupProcess.HasExited) {
        $State.StandardInputCloseAttempted = $true
        $cleanupProcess.StandardInput.Close()
      }
    } },
    [pscustomobject]@{ Name = ($NamePrefix + "_PROCESS_TERMINATE"); Operation = {
      if ($cleanupProcessStarted -and $null -ne $cleanupProcess) {
        $State.ProcessTerminationAttempted = $true
        if (-not $cleanupProcess.HasExited) {
          $cleanupProcess.Kill()
          [void]$cleanupProcess.WaitForExit(5000)
        }
        Assert-Condition -Condition $cleanupProcess.HasExited -Code "staged_start_termination_not_observed"
        $State.ProcessTerminationObserved = $true
      }
    } },
    [pscustomobject]@{ Name = ($NamePrefix + "_LOCAL_PID_REMOVE"); Operation = {
      if ($State.LocalPidAddAttempted) {
        $State.LocalPidRemovalAttempted = $true
        Assert-Condition -Condition ($cleanupProcessStarted -and $State.ProcessTerminationObserved -and $cleanupProcess.HasExited) `
          -Code "staged_start_pid_removed_before_exit"
        Update-WorkerPidManifest -RunDirectory $State.RunDirectory -ProcessId $cleanupProcess.Id `
          -ApplicationName $State.ApplicationName -Operation "remove"
        $State.LocalPidRecorded = $false
      }
    } },
    [pscustomobject]@{ Name = ($NamePrefix + "_EXECUTE_PID_REMOVE"); Operation = {
      if ($State.ExecutePidAddAttempted) {
        $State.ExecutePidRemovalAttempted = $true
        Assert-Condition -Condition ($cleanupProcessStarted -and $State.ProcessTerminationObserved -and $cleanupProcess.HasExited) `
          -Code "staged_start_pid_removed_before_exit"
        Update-ExecuteWorkerManifest -ExecutionContext $State.ExecutionContext -ProcessId $cleanupProcess.Id -Operation "remove"
        $State.ExecutePidRecorded = $false
      }
    } }
  )
}

function Start-StagedInstallationHolder {
  param(
    [Parameter(Mandatory = $true)][object]$Connection,
    [Parameter(Mandatory = $true)][string]$PsqlPath,
    [Parameter(Mandatory = $true)][string]$RunDirectory,
    [Parameter(Mandatory = $true)][string]$AuthorityId,
    [Parameter(Mandatory = $true)][string]$ActivityId
  )
  Assert-Condition -Condition ($AuthorityId -cmatch '^[0-9a-f-]{36}$' -and $ActivityId -cmatch '^[0-9a-f-]{36}$') -Code "staged_holder_identity_rejected" -FailureClass "source_integrity_rejection"
  $stageA = @"
begin;
select set_config('request.jwt.claim.sub', '$AuthorityId', true);
set local role authenticated;
update public.activities
set description = coalesce(description, '') || ' [instalación]'
where id = '$ActivityId'::uuid;
select 'INSTALL_ACTIVITY_UPDATED|' || case when exists (select 1 from public.activities where id = '$ActivityId'::uuid and description like '%[instalación]%') then 1 else 0 end;
"@
  $stageB = @"
select 'INSTALL_PERIOD_READ|' || case when (select count(*) from public.academic_periods) = 5 then 1 else 0 end;
commit;
  select 'INSTALL_HOLDER_COMMITTED|1|' || floor(extract(epoch from pg_catalog.clock_timestamp()) * 1000)::bigint::text;
"@
  $applicationName = "sitaa_sem01_install_holder"
  $stdoutLines = New-Object System.Collections.ArrayList
  $stderrLines = New-Object System.Collections.ArrayList
  $executionContext = if (Test-ObjectProperty -Value $Connection -Name "ExecutionContext") { $Connection.ExecutionContext } else { $null }
  $startInfo = New-StagedPsqlStartInfo -PsqlPath $PsqlPath -Connection $Connection -ApplicationName $applicationName -StatementTimeoutMilliseconds 30000 -LockTimeoutMilliseconds 30000
  $process = $null
  $processStarted = $false
  $worker = $null
  $localPidRecorded = $false
  $executePidRecorded = $false
  $primaryError = $null
  $ownershipState = [pscustomobject]@{
    Process = $null
    ProcessStarted = $false
    Worker = $null
    StartInfo = $startInfo
    StartInfoMaterialClearAttempted = $false
    StartInfoMaterialCleared = $false
    StandardInputCloseAttempted = $false
    ProcessTerminationAttempted = $false
    ProcessTerminationObserved = $false
    LocalPidAddAttempted = $false
    LocalPidRecorded = $false
    LocalPidRemovalAttempted = $false
    ExecutePidAddAttempted = $false
    ExecutePidRecorded = $false
    ExecutePidRemovalAttempted = $false
    RunDirectory = $RunDirectory
    ApplicationName = $applicationName
    ExecutionContext = $executionContext
    CleanupResult = $null
    PrimaryErrorRecord = $null
    RethrowErrorRecord = $null
  }
  try {
    $process = New-Object System.Diagnostics.Process
    $process.StartInfo = $startInfo
    Assert-Condition -Condition ($process.Start()) -Code "staged_worker_start_rejected" -FailureClass "worker_crash"
    $processStarted = $true
    $ownershipState.Process = $process
    $ownershipState.ProcessStarted = $true
    Clear-PsqlStartInfoMaterial -State $ownershipState -StartInfo $startInfo
    $stdoutReadTask = $process.StandardOutput.ReadLineAsync()
    $stderrReadTask = $process.StandardError.ReadLineAsync()
    $worker = [pscustomobject]@{
      Process = $process
      StdoutLines = $stdoutLines
      StderrLines = $stderrLines
      StdoutReadTask = $stdoutReadTask
      StderrReadTask = $stderrReadTask
      StageA = $stageA
      StageB = $stageB
      StageState = "started"
      ApplicationName = $applicationName
      RunDirectory = $RunDirectory
      ExecutionContext = $executionContext
      StartedAt = [DateTime]::UtcNow
    }
    $ownershipState.Worker = $worker
    $ownershipState.LocalPidAddAttempted = $true
    Update-WorkerPidManifest -RunDirectory $RunDirectory -ProcessId $process.Id -ApplicationName $applicationName -Operation "add"
    $localPidRecorded = $true
    $ownershipState.LocalPidRecorded = $true
    if ($null -ne $executionContext) {
      $ownershipState.ExecutePidAddAttempted = $true
      Update-ExecuteWorkerManifest -ExecutionContext $executionContext -ProcessId $process.Id -Operation "add"
      $executePidRecorded = $true
      $ownershipState.ExecutePidRecorded = $true
    }
    Assert-Condition -Condition ($processStarted -and $null -ne $worker -and $localPidRecorded -and
      ($null -eq $executionContext -or $executePidRecorded)) -Code "staged_worker_ownership_incomplete" -FailureClass "postcondition_rejection"
    return $worker
  }
  catch {
    $primaryError = $_
    $ownershipState.PrimaryErrorRecord = $_
    $ownershipState.CleanupResult = Invoke-StagedProcessStartFailureCleanup -State $ownershipState -NamePrefix "INSTALL_HOLDER_START" `
      -FallbackProcess $process -FallbackProcessStarted $processStarted -FallbackStartInfo $startInfo
    $ownershipState.RethrowErrorRecord = $primaryError
    throw $primaryError
  }
}

function Send-StagedInstallationHolderStage {
  param(
    [Parameter(Mandatory = $true)][object]$Worker,
    [Parameter(Mandatory = $true)][ValidateSet("A", "B")][string]$Stage
  )
  $nextState = Get-StagedWorkerNextState -CurrentState ([string]$Worker.StageState) -Stage $Stage -ProcessHasExited $Worker.Process.HasExited
  $sql = if ($Stage -ceq "A") { [string]$Worker.StageA } else { [string]$Worker.StageB }
  Assert-Condition -Condition (-not [string]::IsNullOrWhiteSpace($sql)) -Code "staged_worker_sql_missing" -FailureClass "source_integrity_rejection"
  $sentMonotonicTimestamp = Get-MonotonicTimestamp
  $Worker.Process.StandardInput.Write($sql.Trim() + "`n")
  $Worker.Process.StandardInput.Flush()
  $Worker.StageState = $nextState
  if ($Stage -ceq "B") {
    $Worker.Process.StandardInput.Close()
  }
  return [pscustomobject]@{
    Stage = $Stage
    SentMonotonicTimestamp = [long]$sentMonotonicTimestamp
  }
}

function Wait-StagedInstallationHolderMarker {
  param(
    [Parameter(Mandatory = $true)][object]$Worker,
    [Parameter(Mandatory = $true)][ValidateSet("INSTALL_ACTIVITY_UPDATED", "INSTALL_PERIOD_READ", "INSTALL_HOLDER_COMMITTED")][string]$Marker,
    [Parameter(Mandatory = $true)][object]$StageRequest,
    [ValidateRange(1, 600000)][int]$TimeoutMilliseconds = $script:ObserverTimeoutMilliseconds
  )
  Assert-Condition -Condition ($StageRequest.Stage -cin @("A", "B") -and [long]$StageRequest.SentMonotonicTimestamp -ge 0) -Code "staged_worker_request_rejected" -FailureClass "source_integrity_rejection"
  $expectedStage = if ($Marker -ceq "INSTALL_ACTIVITY_UPDATED") { "A" } else { "B" }
  Assert-Condition -Condition ([string]$StageRequest.Stage -ceq $expectedStage) -Code "staged_worker_marker_stage_request_rejected" -FailureClass "source_integrity_rejection"
  while ($true) {
    $beforeReadTimestamp = Get-MonotonicTimestamp
    $beforeReadElapsed = Get-MonotonicElapsedMilliseconds -StartTimestamp ([long]$StageRequest.SentMonotonicTimestamp) -EndTimestamp $beforeReadTimestamp
    Assert-HardMonotonicDeadline -ElapsedMilliseconds $beforeReadElapsed -TimeoutMilliseconds $TimeoutMilliseconds -FailureCode "staged_worker_marker_timeout"
    Read-StagedPsqlWorkerStreams -Worker $Worker
    $observedMonotonicTimestamp = Get-MonotonicTimestamp
    $commandElapsedMilliseconds = Get-MonotonicElapsedMilliseconds -StartTimestamp ([long]$StageRequest.SentMonotonicTimestamp) -EndTimestamp $observedMonotonicTimestamp
    Assert-HardMonotonicDeadline -ElapsedMilliseconds $commandElapsedMilliseconds -TimeoutMilliseconds $TimeoutMilliseconds -FailureCode "staged_worker_marker_timeout"
    $matches = @($Worker.StdoutLines | Where-Object { ([string]$_).StartsWith($Marker + "|", [System.StringComparison]::Ordinal) })
    Assert-Condition -Condition ($matches.Count -le 1) -Code "staged_worker_marker_duplicate_rejected" -FailureClass "source_integrity_rejection"
    if ($matches.Count -eq 1) {
      $parts = @(([string]$matches[0]).Split('|'))
      $serverEpochMilliseconds = $null
      if ($Marker -ceq "INSTALL_HOLDER_COMMITTED") {
        $commitMarker = ConvertFrom-InstallationHolderCommitMarker -Lines @([string]$matches[0])
        $serverEpochMilliseconds = $commitMarker.CommitMarkerEpochMilliseconds
      }
      else {
        Assert-Condition -Condition ($parts.Count -eq 2 -and $parts[1] -ceq "1") -Code "staged_worker_marker_value_rejected"
      }
      $acceptedMonotonicTimestamp = Get-MonotonicTimestamp
      $acceptedElapsedMilliseconds = Get-MonotonicElapsedMilliseconds -StartTimestamp ([long]$StageRequest.SentMonotonicTimestamp) -EndTimestamp $acceptedMonotonicTimestamp
      Assert-HardMonotonicDeadline -ElapsedMilliseconds $acceptedElapsedMilliseconds -TimeoutMilliseconds $TimeoutMilliseconds -FailureCode "staged_worker_late_marker_rejected"
      if ($Marker -ceq "INSTALL_ACTIVITY_UPDATED") {
        Confirm-StagedWorkerStageA -Worker $Worker -ProcessHasExited $Worker.Process.HasExited
      }
      return [pscustomobject]@{
        Marker = $Marker
        Value = "1"
        CommandElapsedMilliseconds = [double]$acceptedElapsedMilliseconds
        SentMonotonicTimestamp = [long]$StageRequest.SentMonotonicTimestamp
        ObservedMonotonicTimestamp = [long]$acceptedMonotonicTimestamp
        ObservedAtUtc = [DateTime]::UtcNow
        ServerEpochMilliseconds = $serverEpochMilliseconds
      }
    }
    Assert-HardMonotonicDeadline -ElapsedMilliseconds $commandElapsedMilliseconds -TimeoutMilliseconds $TimeoutMilliseconds -FailureCode "staged_worker_marker_timeout"
    Assert-Condition -Condition (-not $Worker.Process.HasExited) -Code "staged_worker_exited_before_marker" -FailureClass "worker_crash"
    Start-Sleep -Milliseconds $script:ObserverPollMilliseconds
  }
}

function Wait-StagedInstallationHolder {
  param(
    [Parameter(Mandatory = $true)][object]$Worker,
    [ValidateRange(1, 600000)][int]$TimeoutMilliseconds,
    [switch]$KeepRawLogs
  )
  $timedOut = -not $Worker.Process.WaitForExit($TimeoutMilliseconds)
  if ($timedOut) {
    try { $Worker.Process.StandardInput.Close() } catch { }
    try { $Worker.Process.Kill() } catch { }
    [void]$Worker.Process.WaitForExit(5000)
  }
  Assert-Condition -Condition $Worker.Process.HasExited -Code "staged_worker_termination_not_observed"
  $completedAt = [DateTime]::UtcNow
  $streamDeadline = [DateTime]::UtcNow.AddSeconds(5)
  do {
    Read-StagedPsqlWorkerStreams -Worker $Worker
    if ($null -eq $Worker.StdoutReadTask -and $null -eq $Worker.StderrReadTask) { break }
    Start-Sleep -Milliseconds 10
  } while ([DateTime]::UtcNow -lt $streamDeadline)
  Assert-Condition -Condition ($null -eq $Worker.StdoutReadTask -and $null -eq $Worker.StderrReadTask) -Code "staged_worker_stream_drain_rejected"
  Assert-Condition -Condition (Test-StagedWorkerPidRemovalEligible -ProcessHasExited $Worker.Process.HasExited) -Code "staged_worker_pid_removed_before_exit"
  Update-WorkerPidManifest -RunDirectory $Worker.RunDirectory -ProcessId $Worker.Process.Id -ApplicationName $Worker.ApplicationName -Operation "remove"
  Update-ExecuteWorkerManifest -ExecutionContext $Worker.ExecutionContext -ProcessId $Worker.Process.Id -Operation "remove"
  $stdout = (@($Worker.StdoutLines) -join "`n") + "`n"
  $stderr = (@($Worker.StderrLines) -join "`n") + "`n"
  $rawBase = Join-Path $Worker.RunDirectory ("raw_" + $Worker.ApplicationName)
  $stdoutPath = $rawBase + ".stdout.local.txt"
  $stderrPath = $rawBase + ".stderr.local.txt"
  Write-ExternalUtf8File -Path $stdoutPath -Content $stdout
  Write-ExternalUtf8File -Path $stderrPath -Content $stderr
  if (-not $KeepRawLogs) {
    Remove-Item -LiteralPath $stdoutPath, $stderrPath -Force -ErrorAction SilentlyContinue
  }
  $exitCode = if ($timedOut) { -1 } else { $Worker.Process.ExitCode }
  $Worker.StageState = "completed"
  [void]$script:WorkerResults.Add([pscustomobject]@{
    ScenarioId = $script:CurrentScenario
    ExitCode = $exitCode
    TimedOut = $timedOut
    Deadlock = [bool](($stderr + "`n" + $stdout) -match '(?i)40P01|deadlock detected')
  })
  return [pscustomobject]@{
    ExitCode = $exitCode
    TimedOut = $timedOut
    Stdout = $stdout
    Stderr = $stderr
    ElapsedMilliseconds = [int]($completedAt - $Worker.StartedAt).TotalMilliseconds
    CompletedAtUtc = $completedAt
  }
}

function Stop-StagedInstallationHolder {
  param([AllowNull()][object]$Worker)
  if ($null -eq $Worker) { return }
  if (-not $Worker.Process.HasExited) {
    try { $Worker.Process.StandardInput.Close() } catch { }
    try { $Worker.Process.Kill() } catch { }
    [void]$Worker.Process.WaitForExit(5000)
  }
  Assert-Condition -Condition $Worker.Process.HasExited -Code "staged_worker_termination_not_observed"
  Assert-Condition -Condition (Test-StagedWorkerPidRemovalEligible -ProcessHasExited $Worker.Process.HasExited) -Code "staged_worker_pid_removed_before_exit"
  Update-WorkerPidManifest -RunDirectory $Worker.RunDirectory -ProcessId $Worker.Process.Id -ApplicationName $Worker.ApplicationName -Operation "remove"
  Update-ExecuteWorkerManifest -ExecutionContext $Worker.ExecutionContext -ProcessId $Worker.Process.Id -Operation "remove"
  $Worker.StageState = "completed"
}

function Start-StagedAuthorityLossHolder {
  param(
    [Parameter(Mandatory = $true)][object]$Connection,
    [Parameter(Mandatory = $true)][string]$PsqlPath,
    [Parameter(Mandatory = $true)][string]$RunDirectory
  )
  $stageA = @"
begin;
select pg_catalog.pg_advisory_xact_lock($($script:Sem01AdvisoryKeyOne), $($script:Sem01AdvisoryKeyTwo));
select 'MS20_HOLDER_LOCKED|1';
"@
  $stageB = @'
rollback;
select 'MS20_HOLDER_RELEASED|1';
'@
  $applicationName = "sitaa_sem01_ms20_holder"
  $stdoutLines = New-Object System.Collections.ArrayList
  $stderrLines = New-Object System.Collections.ArrayList
  $executionContext = if (Test-ObjectProperty -Value $Connection -Name "ExecutionContext") { $Connection.ExecutionContext } else { $null }
  $startInfo = New-StagedPsqlStartInfo -PsqlPath $PsqlPath -Connection $Connection -ApplicationName $applicationName `
    -StatementTimeoutMilliseconds 30000 -LockTimeoutMilliseconds 30000
  $process = $null
  $processStarted = $false
  $worker = $null
  $localPidRecorded = $false
  $executePidRecorded = $false
  $primaryError = $null
  $ownershipState = [pscustomobject]@{
    Process = $null
    ProcessStarted = $false
    Worker = $null
    StartInfo = $startInfo
    StartInfoMaterialClearAttempted = $false
    StartInfoMaterialCleared = $false
    StandardInputCloseAttempted = $false
    ProcessTerminationAttempted = $false
    ProcessTerminationObserved = $false
    LocalPidAddAttempted = $false
    LocalPidRecorded = $false
    LocalPidRemovalAttempted = $false
    ExecutePidAddAttempted = $false
    ExecutePidRecorded = $false
    ExecutePidRemovalAttempted = $false
    RunDirectory = $RunDirectory
    ApplicationName = $applicationName
    ExecutionContext = $executionContext
    CleanupResult = $null
    PrimaryErrorRecord = $null
    RethrowErrorRecord = $null
  }
  try {
    $process = New-Object System.Diagnostics.Process
    $process.StartInfo = $startInfo
    Assert-Condition -Condition ($process.Start()) -Code "ms20_staged_holder_start_rejected" -FailureClass "worker_crash"
    $processStarted = $true
    $ownershipState.Process = $process
    $ownershipState.ProcessStarted = $true
    Clear-PsqlStartInfoMaterial -State $ownershipState -StartInfo $startInfo
    $stdoutReadTask = $process.StandardOutput.ReadLineAsync()
    $stderrReadTask = $process.StandardError.ReadLineAsync()
    $worker = [pscustomobject]@{
      Process = $process
      StdoutLines = $stdoutLines
      StderrLines = $stderrLines
      StdoutReadTask = $stdoutReadTask
      StderrReadTask = $stderrReadTask
      StageA = $stageA
      StageB = $stageB
      StageState = "started"
      ApplicationName = $applicationName
      RunDirectory = $RunDirectory
      ExecutionContext = $executionContext
      StartedAt = [DateTime]::UtcNow
    }
    $ownershipState.Worker = $worker
    $ownershipState.LocalPidAddAttempted = $true
    Update-WorkerPidManifest -RunDirectory $RunDirectory -ProcessId $process.Id -ApplicationName $applicationName -Operation "add"
    $localPidRecorded = $true
    $ownershipState.LocalPidRecorded = $true
    if ($null -ne $executionContext) {
      $ownershipState.ExecutePidAddAttempted = $true
      Update-ExecuteWorkerManifest -ExecutionContext $executionContext -ProcessId $process.Id -Operation "add"
      $executePidRecorded = $true
      $ownershipState.ExecutePidRecorded = $true
    }
    Assert-Condition -Condition ($processStarted -and $null -ne $worker -and $localPidRecorded -and
      ($null -eq $executionContext -or $executePidRecorded)) -Code "ms20_staged_holder_ownership_incomplete" -FailureClass "postcondition_rejection"
    return $worker
  }
  catch {
    $primaryError = $_
    $ownershipState.PrimaryErrorRecord = $_
    $ownershipState.CleanupResult = Invoke-StagedProcessStartFailureCleanup -State $ownershipState -NamePrefix "MS20_HOLDER_START" `
      -FallbackProcess $process -FallbackProcessStarted $processStarted -FallbackStartInfo $startInfo
    $ownershipState.RethrowErrorRecord = $primaryError
    throw $primaryError
  }
}

function Wait-StagedAuthorityLossHolderMarker {
  param(
    [Parameter(Mandatory = $true)][object]$Worker,
    [Parameter(Mandatory = $true)][ValidateSet("MS20_HOLDER_LOCKED", "MS20_HOLDER_RELEASED")][string]$Marker,
    [Parameter(Mandatory = $true)][object]$StageRequest,
    [ValidateRange(1, 600000)][int]$TimeoutMilliseconds = $script:ObserverTimeoutMilliseconds
  )
  $expectedStage = if ($Marker -ceq "MS20_HOLDER_LOCKED") { "A" } else { "B" }
  Assert-Condition -Condition ([string]$StageRequest.Stage -ceq $expectedStage -and [long]$StageRequest.SentMonotonicTimestamp -ge 0) -Code "ms20_staged_marker_request_rejected" -FailureClass "source_integrity_rejection"
  while ($true) {
    $beforeReadTimestamp = Get-MonotonicTimestamp
    $beforeReadElapsed = Get-MonotonicElapsedMilliseconds -StartTimestamp ([long]$StageRequest.SentMonotonicTimestamp) -EndTimestamp $beforeReadTimestamp
    Assert-HardMonotonicDeadline -ElapsedMilliseconds $beforeReadElapsed -TimeoutMilliseconds $TimeoutMilliseconds -FailureCode "ms20_staged_marker_timeout"
    Read-StagedPsqlWorkerStreams -Worker $Worker
    $observedTimestamp = Get-MonotonicTimestamp
    $elapsedMilliseconds = Get-MonotonicElapsedMilliseconds -StartTimestamp ([long]$StageRequest.SentMonotonicTimestamp) -EndTimestamp $observedTimestamp
    Assert-HardMonotonicDeadline -ElapsedMilliseconds $elapsedMilliseconds -TimeoutMilliseconds $TimeoutMilliseconds -FailureCode "ms20_staged_marker_timeout"
    $matches = @($Worker.StdoutLines | Where-Object { ([string]$_).StartsWith($Marker + "|", [System.StringComparison]::Ordinal) })
    Assert-Condition -Condition ($matches.Count -le 1) -Code "ms20_staged_marker_duplicate_rejected" -FailureClass "source_integrity_rejection"
    if ($matches.Count -eq 1) {
      $parts = @(([string]$matches[0]).Split('|'))
      Assert-Condition -Condition ($parts.Count -eq 2 -and $parts[1] -ceq "1") -Code "ms20_staged_marker_value_rejected"
      $acceptedTimestamp = Get-MonotonicTimestamp
      $acceptedElapsed = Get-MonotonicElapsedMilliseconds -StartTimestamp ([long]$StageRequest.SentMonotonicTimestamp) -EndTimestamp $acceptedTimestamp
      Assert-HardMonotonicDeadline -ElapsedMilliseconds $acceptedElapsed -TimeoutMilliseconds $TimeoutMilliseconds -FailureCode "ms20_staged_late_marker_rejected"
      if ($Marker -ceq "MS20_HOLDER_LOCKED") {
        Confirm-StagedWorkerStageA -Worker $Worker -ProcessHasExited $Worker.Process.HasExited
      }
      return [pscustomobject]@{ Marker = $Marker; Value = "1"; CommandElapsedMilliseconds = [double]$acceptedElapsed }
    }
    Assert-Condition -Condition (-not $Worker.Process.HasExited) -Code "ms20_staged_holder_exited_before_marker" -FailureClass "worker_crash"
    Start-Sleep -Milliseconds $script:ObserverPollMilliseconds
  }
}

function Get-InstallationObserverSql {
  param([Parameter(Mandatory = $true)][ValidateSet("readiness", "holder_lock", "wait_direction")][string]$Command)
  if ($Command -ceq "readiness") {
    return "select 'INSTALLATION_OBSERVER_READY|1';"
  }
  if ($Command -ceq "holder_lock") {
    return @'
select 'INSTALLATION_HOLDER_LOCK|' || case when exists (
  select 1
  from pg_catalog.pg_stat_activity activity
  join pg_catalog.pg_locks lock on lock.pid = activity.pid
  where activity.application_name = 'sitaa_sem01_install_holder'
    and lock.relation = 'public.activities'::regclass
    and lock.mode = 'RowExclusiveLock'
    and lock.granted
) then 1 else 0 end;
'@
  }
  return @'
with migration_activity as materialized (
  select pid, query_start,
    floor(extract(epoch from query_start) * 1000)::bigint as lock_query_start_epoch_ms
  from pg_catalog.pg_stat_activity
  where application_name = 'sitaa_sem01_install_migration'
), holder_activity as materialized (
  select pid
  from pg_catalog.pg_stat_activity
  where application_name = 'sitaa_sem01_install_holder'
), clock_sample as materialized (
  select floor(extract(epoch from pg_catalog.clock_timestamp()) * 1000)::bigint as observation_epoch_ms
), observation as (
  select
    (select count(*) from migration_activity) = 1 as exactly_one_migration,
    (select count(*) from holder_activity) = 1 as exactly_one_holder,
    exists (
      select 1 from migration_activity activity
      join pg_catalog.pg_locks lock on lock.pid = activity.pid
      where lock.relation = 'public.activities'::regclass
        and lock.mode = 'ShareRowExclusiveLock' and not lock.granted
    ) as migration_waits_for_activities,
    exists (
      select 1 from holder_activity activity
      join pg_catalog.pg_locks lock on lock.pid = activity.pid
      where lock.relation = 'public.activities'::regclass
        and lock.mode = 'RowExclusiveLock' and lock.granted
    ) as holder_lock_granted,
    not exists (
      select 1 from migration_activity activity
      join pg_catalog.pg_locks lock on lock.pid = activity.pid
      where lock.relation = 'public.academic_periods'::regclass
        and lock.mode = 'AccessExclusiveLock'
    ) as academic_periods_access_exclusive_absent,
    exists (select 1 from holder_activity) as holder_alive,
    exists (select 1 from migration_activity) as migration_alive,
    coalesce((select lock_query_start_epoch_ms from migration_activity), 0) as lock_query_start_epoch_ms,
    (select observation_epoch_ms from clock_sample) as observation_epoch_ms
), measured as (
  select *, observation_epoch_ms - lock_query_start_epoch_ms as wait_age_ms
  from observation
)
select case
  when exactly_one_migration and exactly_one_holder
   and migration_waits_for_activities and holder_lock_granted
   and academic_periods_access_exclusive_absent and holder_alive and migration_alive
   and lock_query_start_epoch_ms > 0 and observation_epoch_ms >= lock_query_start_epoch_ms
  then 'INSTALLATION_WAIT_DIRECTION|1|' || wait_age_ms::text || '|' || lock_query_start_epoch_ms::text || '|' || observation_epoch_ms::text
  else 'INSTALLATION_WAIT_PENDING|1'
end
from measured;
'@
}

function Start-PersistentInstallationObserver {
  param(
    [Parameter(Mandatory = $true)][object]$Connection,
    [Parameter(Mandatory = $true)][string]$PsqlPath,
    [Parameter(Mandatory = $true)][string]$RunDirectory
  )
  $applicationName = "sitaa_sem01_install_observer"
  $stdoutLines = New-Object System.Collections.ArrayList
  $stderrLines = New-Object System.Collections.ArrayList
  $executionContext = if (Test-ObjectProperty -Value $Connection -Name "ExecutionContext") { $Connection.ExecutionContext } else { $null }
  $startInfo = New-StagedPsqlStartInfo -PsqlPath $PsqlPath -Connection $Connection -ApplicationName $applicationName `
    -StatementTimeoutMilliseconds $script:InstallationObserverCommandTimeoutMilliseconds -LockTimeoutMilliseconds $script:InstallationObserverCommandTimeoutMilliseconds -ReadOnly
  $process = $null
  $processStarted = $false
  $worker = $null
  $localPidRecorded = $false
  $executePidRecorded = $false
  $primaryError = $null
  $ownershipState = [pscustomobject]@{
    Process = $null
    ProcessStarted = $false
    Worker = $null
    StartInfo = $startInfo
    StartInfoMaterialClearAttempted = $false
    StartInfoMaterialCleared = $false
    StandardInputCloseAttempted = $false
    ProcessTerminationAttempted = $false
    ProcessTerminationObserved = $false
    LocalPidAddAttempted = $false
    LocalPidRecorded = $false
    LocalPidRemovalAttempted = $false
    ExecutePidAddAttempted = $false
    ExecutePidRecorded = $false
    ExecutePidRemovalAttempted = $false
    RunDirectory = $RunDirectory
    ApplicationName = $applicationName
    ExecutionContext = $executionContext
    CleanupResult = $null
    PrimaryErrorRecord = $null
    RethrowErrorRecord = $null
  }
  try {
    $process = New-Object System.Diagnostics.Process
    $process.StartInfo = $startInfo
    Assert-Condition -Condition ($process.Start()) -Code "installation_observer_start_rejected" -FailureClass "worker_crash"
    $processStarted = $true
    $ownershipState.Process = $process
    $ownershipState.ProcessStarted = $true
    Clear-PsqlStartInfoMaterial -State $ownershipState -StartInfo $startInfo
    $stdoutReadTask = $process.StandardOutput.ReadLineAsync()
    $stderrReadTask = $process.StandardError.ReadLineAsync()
    $worker = [pscustomobject]@{
      Process = $process
      StdoutLines = $stdoutLines
      StderrLines = $stderrLines
      StdoutReadTask = $stdoutReadTask
      StderrReadTask = $stderrReadTask
      StageState = "started"
      ApplicationName = $applicationName
      RunDirectory = $RunDirectory
      ExecutionContext = $executionContext
      StartedAt = [DateTime]::UtcNow
    }
    $ownershipState.Worker = $worker
    $ownershipState.LocalPidAddAttempted = $true
    Update-WorkerPidManifest -RunDirectory $RunDirectory -ProcessId $process.Id -ApplicationName $applicationName -Operation "add"
    $localPidRecorded = $true
    $ownershipState.LocalPidRecorded = $true
    if ($null -ne $executionContext) {
      $ownershipState.ExecutePidAddAttempted = $true
      Update-ExecuteWorkerManifest -ExecutionContext $executionContext -ProcessId $process.Id -Operation "add"
      $executePidRecorded = $true
      $ownershipState.ExecutePidRecorded = $true
    }
    Assert-Condition -Condition ($processStarted -and $null -ne $worker -and $localPidRecorded -and
      ($null -eq $executionContext -or $executePidRecorded)) -Code "installation_observer_ownership_incomplete" -FailureClass "postcondition_rejection"
    return $worker
  }
  catch {
    $primaryError = $_
    $ownershipState.PrimaryErrorRecord = $_
    $ownershipState.CleanupResult = Invoke-StagedProcessStartFailureCleanup -State $ownershipState -NamePrefix "INSTALL_OBSERVER_START" `
      -FallbackProcess $process -FallbackProcessStarted $processStarted -FallbackStartInfo $startInfo
    $ownershipState.RethrowErrorRecord = $primaryError
    throw $primaryError
  }
}

function Send-PersistentInstallationObserverCommand {
  param(
    [Parameter(Mandatory = $true)][object]$Observer,
    [Parameter(Mandatory = $true)][ValidateSet("readiness", "holder_lock", "wait_direction")][string]$Command
  )
  Read-StagedPsqlWorkerStreams -Worker $Observer
  Assert-Condition -Condition (-not $Observer.Process.HasExited) -Code "installation_observer_exited" -FailureClass "worker_crash"
  $startIndex = $Observer.StdoutLines.Count
  $sentMonotonicTimestamp = Get-MonotonicTimestamp
  $Observer.Process.StandardInput.Write((Get-InstallationObserverSql -Command $Command).Trim() + "`n")
  $Observer.Process.StandardInput.Flush()
  return [pscustomobject]@{
    Command = $Command
    StartIndex = $startIndex
    SentMonotonicTimestamp = [long]$sentMonotonicTimestamp
  }
}

function Wait-PersistentInstallationObserverResponse {
  param(
    [Parameter(Mandatory = $true)][object]$Observer,
    [Parameter(Mandatory = $true)][object]$Request,
    [ValidateRange(1, 600000)][int]$TimeoutMilliseconds = $script:InstallationObserverCommandTimeoutMilliseconds
  )
  Assert-Condition -Condition ([long]$Request.SentMonotonicTimestamp -ge 0) -Code "installation_observer_request_rejected" -FailureClass "source_integrity_rejection"
  while ($true) {
    $beforeReadTimestamp = Get-MonotonicTimestamp
    $beforeReadElapsed = Get-MonotonicElapsedMilliseconds -StartTimestamp ([long]$Request.SentMonotonicTimestamp) -EndTimestamp $beforeReadTimestamp
    Assert-HardMonotonicDeadline -ElapsedMilliseconds $beforeReadElapsed -TimeoutMilliseconds $TimeoutMilliseconds -FailureCode "installation_observer_command_timeout"
    Read-StagedPsqlWorkerStreams -Worker $Observer
    $observedMonotonicTimestamp = Get-MonotonicTimestamp
    $commandElapsedMilliseconds = Get-MonotonicElapsedMilliseconds -StartTimestamp ([long]$Request.SentMonotonicTimestamp) -EndTimestamp $observedMonotonicTimestamp
    Assert-HardMonotonicDeadline -ElapsedMilliseconds $commandElapsedMilliseconds -TimeoutMilliseconds $TimeoutMilliseconds -FailureCode "installation_observer_command_timeout"
    $newLines = @($Observer.StdoutLines | Select-Object -Skip ([int]$Request.StartIndex))
    $prefixes = switch ([string]$Request.Command) {
      "readiness" { @("INSTALLATION_OBSERVER_READY|") }
      "holder_lock" { @("INSTALLATION_HOLDER_LOCK|") }
      default { @("INSTALLATION_WAIT_PENDING|", "INSTALLATION_WAIT_DIRECTION|") }
    }
    $matches = @($newLines | Where-Object {
      $line = [string]$_
      @($prefixes | Where-Object { $line.StartsWith($_, [System.StringComparison]::Ordinal) }).Count -eq 1
    })
    Assert-Condition -Condition ($matches.Count -le 1) -Code "installation_observer_response_duplicate_rejected" -FailureClass "source_integrity_rejection"
    if ($matches.Count -eq 1) {
      $acceptedMonotonicTimestamp = Get-MonotonicTimestamp
      $acceptedElapsedMilliseconds = Get-MonotonicElapsedMilliseconds -StartTimestamp ([long]$Request.SentMonotonicTimestamp) -EndTimestamp $acceptedMonotonicTimestamp
      Assert-HardMonotonicDeadline -ElapsedMilliseconds $acceptedElapsedMilliseconds -TimeoutMilliseconds $TimeoutMilliseconds -FailureCode "installation_observer_late_response_rejected"
      return [pscustomobject]@{
        Line = [string]$matches[0]
        CommandElapsedMilliseconds = [double]$acceptedElapsedMilliseconds
        SentMonotonicTimestamp = [long]$Request.SentMonotonicTimestamp
        ObservedMonotonicTimestamp = [long]$acceptedMonotonicTimestamp
        ObservedAtUtc = [DateTime]::UtcNow
      }
    }
    Assert-HardMonotonicDeadline -ElapsedMilliseconds $commandElapsedMilliseconds -TimeoutMilliseconds $TimeoutMilliseconds -FailureCode "installation_observer_command_timeout"
    Assert-Condition -Condition (-not $Observer.Process.HasExited) -Code "installation_observer_exited" -FailureClass "worker_crash"
    Start-Sleep -Milliseconds $script:ObserverPollMilliseconds
  }
}

function ConvertFrom-InstallationWaitDirectionMarker {
  param([Parameter(Mandatory = $true)][string[]]$Lines)
  $matches = @($Lines | Where-Object { ([string]$_).StartsWith("INSTALLATION_WAIT_DIRECTION|", [System.StringComparison]::Ordinal) })
  Assert-Condition -Condition ($matches.Count -eq 1) -Code "installation_wait_direction_marker_rejected" -FailureClass "source_integrity_rejection"
  $parts = @(([string]$matches[0]).Split('|'))
  $waitAge = 0L
  $lockQueryStartEpoch = 0L
  $observationEpoch = 0L
  Assert-Condition -Condition ($parts.Count -eq 5 -and $parts[0] -ceq "INSTALLATION_WAIT_DIRECTION" -and $parts[1] -ceq "1" -and
    [long]::TryParse($parts[2], [ref]$waitAge) -and [long]::TryParse($parts[3], [ref]$lockQueryStartEpoch) -and
    [long]::TryParse($parts[4], [ref]$observationEpoch)) -Code "installation_wait_direction_marker_rejected" -FailureClass "source_integrity_rejection"
  Assert-Condition -Condition ($waitAge -ge 0 -and $lockQueryStartEpoch -gt 0 -and $observationEpoch -ge $lockQueryStartEpoch) -Code "installation_wait_server_timestamp_rejected" -FailureClass "source_integrity_rejection"
  Assert-Condition -Condition ($waitAge -le $script:InstallationWaitAgeLimitMilliseconds) -Code "installation_wait_age_rejected" -FailureClass "source_integrity_rejection"
  $serverDelta = $observationEpoch - $lockQueryStartEpoch
  Assert-Condition -Condition ([Math]::Abs([double]($serverDelta - $waitAge)) -le $script:InstallationServerClockRoundingToleranceMilliseconds) -Code "installation_wait_server_clock_inconsistent" -FailureClass "source_integrity_rejection"
  return [pscustomobject]@{
    ServerWaitAgeMilliseconds = [long]$waitAge
    LockQueryStartEpochMilliseconds = [long]$lockQueryStartEpoch
    ObservationEpochMilliseconds = [long]$observationEpoch
  }
}

function ConvertFrom-InstallationHolderCommitMarker {
  param([Parameter(Mandatory = $true)][string[]]$Lines)
  $matches = @($Lines | Where-Object { ([string]$_).StartsWith("INSTALL_HOLDER_COMMITTED|", [System.StringComparison]::Ordinal) })
  Assert-Condition -Condition ($matches.Count -eq 1) -Code "installation_holder_commit_marker_rejected" -FailureClass "source_integrity_rejection"
  $parts = @(([string]$matches[0]).Split('|'))
  $commitMarkerEpoch = 0L
  Assert-Condition -Condition ($parts.Count -eq 3 -and $parts[0] -ceq "INSTALL_HOLDER_COMMITTED" -and $parts[1] -ceq "1" -and
    [long]::TryParse($parts[2], [ref]$commitMarkerEpoch) -and $commitMarkerEpoch -gt 0) -Code "installation_holder_commit_marker_rejected" -FailureClass "source_integrity_rejection"
  return [pscustomobject]@{ CommitMarkerEpochMilliseconds = [long]$commitMarkerEpoch }
}

function Wait-ForInstallationWaitDirection {
  param(
    [Parameter(Mandatory = $true)][object]$Observer,
    [Parameter(Mandatory = $true)][object]$Holder,
    [Parameter(Mandatory = $true)][object]$Migration
  )
  $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
  while ($true) {
    Assert-Condition -Condition ($stopwatch.ElapsedMilliseconds -lt $script:InstallationWaitStartDeadlineMilliseconds) -Code "installation_wait_start_deadline_rejected" -FailureClass "unexpected_timeout"
    $request = Send-PersistentInstallationObserverCommand -Observer $Observer -Command "wait_direction"
    $remaining = [int]($script:InstallationWaitStartDeadlineMilliseconds - $stopwatch.ElapsedMilliseconds)
    Assert-Condition -Condition ($remaining -gt 0) -Code "installation_wait_start_deadline_rejected" -FailureClass "unexpected_timeout"
    $commandTimeout = [Math]::Min($script:InstallationObserverCommandTimeoutMilliseconds, $remaining)
    $response = Wait-PersistentInstallationObserverResponse -Observer $Observer -Request $request -TimeoutMilliseconds $commandTimeout
    Assert-Condition -Condition ($response.CommandElapsedMilliseconds -ge 0 -and $response.CommandElapsedMilliseconds -le $commandTimeout) -Code "installation_observer_command_deadline_rejected" -FailureClass "unexpected_timeout"
    Assert-Condition -Condition ($stopwatch.ElapsedMilliseconds -lt $script:InstallationWaitStartDeadlineMilliseconds) -Code "installation_wait_start_deadline_rejected" -FailureClass "unexpected_timeout"
    Assert-Condition -Condition (-not $Holder.Process.HasExited -and -not $Migration.Process.HasExited) -Code "installation_worker_exited_before_wait" -FailureClass "worker_crash"
    if ($response.Line -ceq "INSTALLATION_WAIT_PENDING|1") {
      Start-Sleep -Milliseconds $script:ObserverPollMilliseconds
      continue
    }
    $waitMarker = ConvertFrom-InstallationWaitDirectionMarker -Lines @($response.Line)
    return [pscustomobject]@{
      WaitObserved = $true
      ServerWaitAgeMilliseconds = [long]$waitMarker.ServerWaitAgeMilliseconds
      LockQueryStartEpochMilliseconds = [long]$waitMarker.LockQueryStartEpochMilliseconds
      ObservationEpochMilliseconds = [long]$waitMarker.ObservationEpochMilliseconds
      ControllerObservationElapsedMilliseconds = [int]$stopwatch.ElapsedMilliseconds
      CommandElapsedMilliseconds = [double]$response.CommandElapsedMilliseconds
      SentMonotonicTimestamp = [long]$response.SentMonotonicTimestamp
      ObservedMonotonicTimestamp = [long]$response.ObservedMonotonicTimestamp
      MigrationActivitiesWaitUnGranted = $true
      HolderLockGranted = $true
      AcademicPeriodsAccessExclusiveAbsent = $true
      HolderAlive = (-not $Holder.Process.HasExited)
      MigrationAlive = (-not $Migration.Process.HasExited)
      ObservedAtUtc = $response.ObservedAtUtc
    }
  }
}

function Close-PersistentInstallationObserver {
  param([AllowNull()][object]$Observer)
  if ($null -ne $Observer -and -not $Observer.Process.HasExited) {
    try { $Observer.Process.StandardInput.Close() } catch { }
  }
}

function Wait-PersistentInstallationObserver {
  param(
    [Parameter(Mandatory = $true)][object]$Observer,
    [ValidateRange(1, 600000)][int]$TimeoutMilliseconds = $script:InstallationHolderProcessExitTimeoutMilliseconds,
    [switch]$KeepRawLogs
  )
  Close-PersistentInstallationObserver -Observer $Observer
  return Wait-StagedInstallationHolder -Worker $Observer -TimeoutMilliseconds $TimeoutMilliseconds -KeepRawLogs:$KeepRawLogs
}

function Stop-PersistentInstallationObserver {
  param([AllowNull()][object]$Observer)
  Stop-StagedInstallationHolder -Worker $Observer
}

function Assert-PsqlApproved {
  param(
    [Parameter(Mandatory = $true)][object]$Result,
    [Parameter(Mandatory = $true)][string]$FailureCode
  )
  if ($Result.TimedOut) {
    Throw-StableFailure -Code "unexpected_timeout" -FailureClass "unexpected_timeout"
  }
  if (($Result.Stderr + "`n" + $Result.Stdout) -match '(?i)40P01|deadlock detected') {
    Throw-StableFailure -Code "postgres_deadlock_40P01" -FailureClass "postgres_deadlock"
  }
  if ($Result.ExitCode -ne 0) {
    $combined = $Result.Stderr + "`n" + $Result.Stdout
    if ($combined -match '(?i)could not connect|connection (?:refused|timed out)|password authentication failed|no pg_hba') {
      Throw-StableFailure -Code $FailureCode -FailureClass "connection_failure"
    }
    Throw-StableFailure -Code $FailureCode -FailureClass "worker_crash"
  }
}

function Assert-ExpectedSqlState {
  param(
    [Parameter(Mandatory = $true)][object]$Result,
    [Parameter(Mandatory = $true)][string]$SqlState,
    [Parameter(Mandatory = $true)][string]$MessagePattern,
    [Parameter(Mandatory = $true)][string]$FailureCode
  )
  if ($Result.TimedOut) {
    Throw-StableFailure -Code "unexpected_timeout" -FailureClass "unexpected_timeout"
  }
  if (($Result.Stderr + "`n" + $Result.Stdout) -match '(?i)40P01|deadlock detected') {
    Throw-StableFailure -Code "postgres_deadlock_40P01" -FailureClass "postgres_deadlock"
  }
  $combined = $Result.Stderr + "`n" + $Result.Stdout
  Assert-Condition -Condition ($Result.ExitCode -ne 0) -Code $FailureCode
  Assert-Condition -Condition ($combined -match ("(?m)(?:ERROR:\s+" + [regex]::Escape($SqlState) + ":|SQLSTATE[=: ]+" + [regex]::Escape($SqlState) + ")")) -Code $FailureCode
  Assert-Condition -Condition ($combined -match $MessagePattern) -Code $FailureCode
}

function Resolve-PsqlProcessTimeoutMilliseconds {
  param(
    [Parameter(Mandatory = $true)][long]$StatementTimeoutMilliseconds,
    [Parameter(Mandatory = $true)][long]$ProcessTimeoutMilliseconds
  )
  if ($ProcessTimeoutMilliseconds -lt 0) {
    Throw-StableFailure -Code "psql_process_timeout_negative_rejected" -FailureClass "source_integrity_rejection"
  }
  if ($ProcessTimeoutMilliseconds -gt 600000) {
    Throw-StableFailure -Code "psql_process_timeout_range_rejected" -FailureClass "source_integrity_rejection"
  }
  if ($ProcessTimeoutMilliseconds -gt 0) {
    return [int]$ProcessTimeoutMilliseconds
  }
  if ($StatementTimeoutMilliseconds -lt 0) {
    Throw-StableFailure -Code "psql_statement_timeout_negative_rejected" -FailureClass "source_integrity_rejection"
  }
  if ($StatementTimeoutMilliseconds -gt 570000) {
    Throw-StableFailure -Code "psql_process_timeout_overflow_rejected" -FailureClass "source_integrity_rejection"
  }
  $resolved = [long]$StatementTimeoutMilliseconds + 30000
  if ($resolved -le 0 -or $resolved -gt 600000) {
    Throw-StableFailure -Code "psql_process_timeout_resolution_rejected" -FailureClass "source_integrity_rejection"
  }
  return [int]$resolved
}

function New-PsqlDisposableOwnershipState {
  param(
    [AllowNull()][string]$SqlFile = $null,
    [Parameter(Mandatory = $true)][string]$RunDirectory
  )
  $canonicalRunDirectory = [System.IO.Path]::GetFullPath($RunDirectory).TrimEnd('\', '/')
  $canonicalPath = if ([string]::IsNullOrWhiteSpace($SqlFile)) { $null } else { [System.IO.Path]::GetFullPath($SqlFile) }
  $state = [pscustomobject]@{
    Path = $canonicalPath
    RunDirectory = $canonicalRunDirectory
    FrozenCanonicalPath = $canonicalPath
    FrozenCanonicalRunDirectory = $canonicalRunDirectory
    FrozenCanonicalFileName = if ($null -eq $canonicalPath) { $null } else { Split-Path -Leaf $canonicalPath }
    FrozenExpectedSha256 = $null
    FrozenExpectedByteLength = $null
    IdentityFrozen = $false
    OwnerState = "none"
    ProcessStartObserved = $false
    ProcessTerminationObserved = $false
    Process = $null
    ProcessId = $null
    ProcessIdObserved = $false
    Worker = $null
    StartInfo = $null
    StartInfoMaterialClearAttempted = $false
    StartInfoMaterialCleared = $false
    LocalPidAddAttempted = $false
    LocalPidRecorded = $false
    LocalPidRemovalAttempted = $false
    ExecutePidAddAttempted = $false
    ExecutePidRecorded = $false
    ExecutePidRemovalAttempted = $false
    CleanupAttempted = $false
    CleanupCompleted = $false
    CleanupInvocationCount = 0
    RemovalAttemptCount = 0
    AbsenceObserved = $false
    SecondaryCleanupErrors = @()
    PrimaryErrorRecord = $null
    PrimaryFailureClass = $null
    PrimaryScenario = $null
    WorkerTransferCount = 0
    CollectionCount = 0
  }
  $state | Add-Member -MemberType ScriptProperty -Name CallerOwns -Value { $this.OwnerState -ceq "caller" }
  $state | Add-Member -MemberType ScriptProperty -Name ControllerOwns -Value { $this.OwnerState -ceq "controller" }
  $state | Add-Member -MemberType ScriptProperty -Name StarterOwns -Value { $this.OwnerState -ceq "starter" }
  $state | Add-Member -MemberType ScriptProperty -Name WorkerOwns -Value { $this.OwnerState -ceq "worker" }
  $state | Add-Member -MemberType ScriptProperty -Name CanonicalPath -Value { $this.FrozenCanonicalPath }
  $state | Add-Member -MemberType ScriptProperty -Name CanonicalRunDirectory -Value { $this.FrozenCanonicalRunDirectory }
  $state | Add-Member -MemberType ScriptProperty -Name CanonicalFileName -Value { $this.FrozenCanonicalFileName }
  $state | Add-Member -MemberType ScriptProperty -Name ExpectedSha256 -Value { $this.FrozenExpectedSha256 }
  $state | Add-Member -MemberType ScriptProperty -Name ExpectedByteLength -Value { $this.FrozenExpectedByteLength }
  return $state
}

function Assert-PsqlDisposableOwnershipInvariant {
  param([Parameter(Mandatory = $true)][object]$State)
  Assert-Condition -Condition ([string]$State.OwnerState -cin @("none", "caller", "controller", "starter", "worker", "completed")) `
    -Code "psql_disposable_owner_state_rejected" -FailureClass "source_integrity_rejection"
  $derivedOwnerCount = @($State.CallerOwns, $State.ControllerOwns, $State.StarterOwns, $State.WorkerOwns | Where-Object { $_ }).Count
  $expectedOwnerCount = if ([string]$State.OwnerState -cin @("caller", "controller", "starter", "worker")) { 1 } else { 0 }
  Assert-Condition -Condition ($derivedOwnerCount -eq $expectedOwnerCount) -Code "psql_disposable_multiple_owners_rejected" `
    -FailureClass "source_integrity_rejection"
  Assert-Condition -Condition (-not ($State.OwnerState -ceq "completed" -and -not $State.CleanupCompleted)) `
    -Code "psql_disposable_completed_state_rejected" -FailureClass "source_integrity_rejection"
  $identityComplete = $State.IdentityFrozen -and
    -not [string]::IsNullOrWhiteSpace([string]$State.CanonicalPath) -and
    -not [string]::IsNullOrWhiteSpace([string]$State.CanonicalRunDirectory) -and
    -not [string]::IsNullOrWhiteSpace([string]$State.CanonicalFileName) -and
    ([string]$State.ExpectedSha256 -cmatch '^[0-9a-f]{64}$') -and [long]$State.ExpectedByteLength -gt 0 -and
    [string]::Equals([System.IO.Path]::GetFullPath([string]$State.Path), [string]$State.CanonicalPath, [System.StringComparison]::OrdinalIgnoreCase) -and
    [string]::Equals([System.IO.Path]::GetFullPath([string]$State.RunDirectory).TrimEnd('\', '/'), [string]$State.CanonicalRunDirectory, [System.StringComparison]::OrdinalIgnoreCase)
  if ([string]$State.OwnerState -ceq "none") {
    Assert-Condition -Condition (-not $State.ProcessStartObserved -and $null -eq $State.Process -and
      $null -eq $State.ProcessId -and -not $State.ProcessIdObserved -and $null -eq $State.Worker -and
      -not $State.CleanupCompleted) -Code "psql_disposable_none_state_rejected" -FailureClass "source_integrity_rejection"
  }
  elseif ([string]$State.OwnerState -cin @("caller", "controller")) {
    Assert-Condition -Condition ($identityComplete -and -not $State.ProcessStartObserved -and $null -eq $State.Process -and
      $null -eq $State.ProcessId -and -not $State.ProcessIdObserved -and $null -eq $State.Worker -and
      -not $State.CleanupCompleted) -Code "psql_disposable_prestart_state_rejected" -FailureClass "source_integrity_rejection"
  }
  elseif ([string]$State.OwnerState -ceq "starter") {
    Assert-Condition -Condition ($identityComplete -and $State.ProcessStartObserved -and $null -ne $State.Process -and
      $null -eq $State.Worker -and -not $State.CleanupCompleted -and
      (($State.ProcessIdObserved -and $null -ne $State.ProcessId -and [int]$State.ProcessId -gt 0) -or
       (-not $State.ProcessIdObserved -and $null -eq $State.ProcessId))) `
      -Code "psql_disposable_starter_state_rejected" -FailureClass "source_integrity_rejection"
  }
  elseif ([string]$State.OwnerState -ceq "worker") {
    $workerMatches = $null -ne $State.Worker -and $null -ne $State.Process -and
      [object]::ReferenceEquals($State.Worker.Process, $State.Process) -and
      [string]::Equals([System.IO.Path]::GetFullPath([string]$State.Worker.SqlFile), [string]$State.CanonicalPath, [System.StringComparison]::OrdinalIgnoreCase)
    Assert-Condition -Condition ($identityComplete -and $State.ProcessStartObserved -and $State.ProcessIdObserved -and
      $null -ne $State.ProcessId -and [int]$State.ProcessId -gt 0 -and $workerMatches -and
      $State.StartInfoMaterialCleared -and -not $State.CleanupCompleted) `
      -Code "psql_disposable_worker_state_rejected" -FailureClass "source_integrity_rejection"
  }
  elseif ([string]$State.OwnerState -ceq "completed") {
    $startInfoClean = $null -eq $State.StartInfo -or -not (Test-PsqlStartInfoContainsPgMaterial -StartInfo $State.StartInfo)
    Assert-Condition -Condition ($State.CleanupCompleted -and $State.AbsenceObserved -and
      (-not $State.ProcessStartObserved -or $State.ProcessTerminationObserved) -and
      ([string]::IsNullOrWhiteSpace([string]$State.CanonicalPath) -or -not (Test-Path -LiteralPath $State.CanonicalPath)) -and
      $startInfoClean) -Code "psql_disposable_completed_invariant_rejected" -FailureClass "source_integrity_rejection"
  }
}

function Get-PsqlDisposableIdentity {
  param(
    [Parameter(Mandatory = $true)][string]$SqlFile,
    [Parameter(Mandatory = $true)][string]$RunDirectory
  )
  [void](Assert-DisposableWorkerSqlPath -SqlFile $SqlFile -RunDirectory $RunDirectory)
  $identity = [pscustomobject]@{
    CanonicalPath = [System.IO.Path]::GetFullPath($SqlFile)
    CanonicalRunDirectory = [System.IO.Path]::GetFullPath($RunDirectory).TrimEnd('\', '/')
    CanonicalFileName = Split-Path -Leaf ([System.IO.Path]::GetFullPath($SqlFile))
  }
  $expectedSha256 = if (Test-Path -LiteralPath $identity.CanonicalPath -PathType Leaf) {
    Get-Sha256 -Path $identity.CanonicalPath
  }
  else { $null }
  $expectedByteLength = if (Test-Path -LiteralPath $identity.CanonicalPath -PathType Leaf) {
    [long](Get-Item -LiteralPath $identity.CanonicalPath -Force).Length
  }
  else { $null }
  return [pscustomobject]@{
    CanonicalPath = [string]$identity.CanonicalPath
    CanonicalRunDirectory = [string]$identity.CanonicalRunDirectory
    CanonicalFileName = [string]$identity.CanonicalFileName
    ExpectedSha256 = $expectedSha256
    ExpectedByteLength = $expectedByteLength
  }
}

function Assert-PsqlDisposableStateIdentity {
  param(
    [Parameter(Mandatory = $true)][object]$State,
    [Parameter(Mandatory = $true)][object]$Identity
  )
  if (-not [string]::IsNullOrWhiteSpace([string]$State.CanonicalPath)) {
    Assert-Condition -Condition ([string]::Equals([string]$State.CanonicalPath, [string]$Identity.CanonicalPath, [System.StringComparison]::OrdinalIgnoreCase)) `
      -Code "psql_disposable_handoff_identity_rejected" -FailureClass "source_integrity_rejection"
  }
  Assert-Condition -Condition ([string]::Equals([string]$State.CanonicalRunDirectory, [string]$Identity.CanonicalRunDirectory, [System.StringComparison]::OrdinalIgnoreCase)) `
    -Code "psql_disposable_handoff_run_directory_rejected" -FailureClass "source_integrity_rejection"
  if (-not [string]::IsNullOrWhiteSpace([string]$State.CanonicalFileName)) {
    Assert-Condition -Condition ([string]$State.CanonicalFileName -ceq [string]$Identity.CanonicalFileName) `
      -Code "psql_disposable_handoff_filename_rejected" -FailureClass "source_integrity_rejection"
  }
  if (-not [string]::IsNullOrWhiteSpace([string]$State.ExpectedSha256) -and
    -not [string]::IsNullOrWhiteSpace([string]$Identity.ExpectedSha256)) {
    Assert-Condition -Condition ([string]$State.ExpectedSha256 -ceq [string]$Identity.ExpectedSha256) `
      -Code "psql_disposable_handoff_hash_rejected" -FailureClass "source_integrity_rejection"
  }
  if ($null -ne $State.ExpectedByteLength -and $null -ne $Identity.ExpectedByteLength) {
    Assert-Condition -Condition ([long]$State.ExpectedByteLength -eq [long]$Identity.ExpectedByteLength) `
      -Code "psql_disposable_handoff_length_rejected" -FailureClass "source_integrity_rejection"
  }
}

function Set-PsqlDisposableFrozenIdentity {
  param(
    [Parameter(Mandatory = $true)][object]$State,
    [Parameter(Mandatory = $true)][object]$Identity
  )
  Assert-PsqlDisposableOwnershipInvariant -State $State
  Assert-Condition -Condition ([string]$State.OwnerState -ceq "none" -and -not $State.IdentityFrozen) `
    -Code "psql_disposable_identity_already_frozen" -FailureClass "source_integrity_rejection"
  Assert-Condition -Condition (-not [string]::IsNullOrWhiteSpace([string]$Identity.CanonicalPath) -and
    -not [string]::IsNullOrWhiteSpace([string]$Identity.CanonicalRunDirectory) -and
    ([string]$Identity.CanonicalFileName -cmatch '^worker_[a-z0-9_]+_[0-9a-f]{32}\.sql$') -and
    ([string]$Identity.ExpectedSha256 -cmatch '^[0-9a-f]{64}$') -and [long]$Identity.ExpectedByteLength -gt 0) `
    -Code "psql_disposable_identity_freeze_rejected" -FailureClass "source_integrity_rejection"
  $State.Path = [string]$Identity.CanonicalPath
  $State.RunDirectory = [string]$Identity.CanonicalRunDirectory
  $State.FrozenCanonicalPath = [string]$Identity.CanonicalPath
  $State.FrozenCanonicalRunDirectory = [string]$Identity.CanonicalRunDirectory
  $State.FrozenCanonicalFileName = [string]$Identity.CanonicalFileName
  $State.FrozenExpectedSha256 = [string]$Identity.ExpectedSha256
  $State.FrozenExpectedByteLength = [long]$Identity.ExpectedByteLength
  $State.IdentityFrozen = $true
}

function New-PsqlVerifiedTransientArtifact {
  param(
    [Parameter(Mandatory = $true)][object]$CreationState,
    [Parameter(Mandatory = $true)][ValidateSet("caller", "controller")][string]$InitialOwner
  )
  Assert-Condition -Condition ($CreationState.Verified -and $CreationState.WriteCompleted -and
    [string]$CreationState.ActualSha256 -ceq [string]$CreationState.ExpectedSha256 -and
    [long]$CreationState.ActualByteLength -eq [long]$CreationState.ExpectedByteLength) `
    -Code "psql_verified_artifact_creation_state_rejected" -FailureClass "source_integrity_rejection"
  $state = New-PsqlDisposableOwnershipState -RunDirectory ([string]$CreationState.CanonicalRunDirectory)
  $identity = [pscustomobject]@{
    CanonicalPath = [string]$CreationState.CanonicalPath
    CanonicalRunDirectory = [string]$CreationState.CanonicalRunDirectory
    CanonicalFileName = [string]$CreationState.CanonicalFileName
    ExpectedSha256 = [string]$CreationState.ExpectedSha256
    ExpectedByteLength = [long]$CreationState.ExpectedByteLength
  }
  Set-PsqlDisposableFrozenIdentity -State $state -Identity $identity
  $state.OwnerState = $InitialOwner
  Assert-PsqlDisposableOwnershipInvariant -State $state
  return [pscustomobject]@{
    Path = [string]$identity.CanonicalPath
    CanonicalPath = [string]$identity.CanonicalPath
    CanonicalRunDirectory = [string]$identity.CanonicalRunDirectory
    CanonicalFileName = [string]$identity.CanonicalFileName
    ExpectedSha256 = [string]$identity.ExpectedSha256
    ExpectedByteLength = [long]$identity.ExpectedByteLength
    OwnershipState = $state
  }
}

function Set-PsqlDisposableCallerOwnership {
  param(
    [Parameter(Mandatory = $true)][object]$State,
    [Parameter(Mandatory = $true)][string]$SqlFile,
    [Parameter(Mandatory = $true)][string]$RunDirectory
  )
  Assert-PsqlDisposableOwnershipInvariant -State $State
  Assert-Condition -Condition ($State.IdentityFrozen -and [string]$State.OwnerState -ceq "none" -and $State.WorkerTransferCount -eq 0 -and
    $State.CleanupInvocationCount -eq 0 -and -not $State.CleanupCompleted) `
    -Code "psql_disposable_caller_ownership_rejected" -FailureClass "source_integrity_rejection"
  $identity = Get-PsqlDisposableIdentity -SqlFile $SqlFile -RunDirectory $RunDirectory
  Assert-PsqlDisposableStateIdentity -State $State -Identity $identity
  $State.OwnerState = "caller"
  Assert-PsqlDisposableOwnershipInvariant -State $State
}

function Set-PsqlDisposableControllerOwnership {
  param(
    [Parameter(Mandatory = $true)][object]$State,
    [Parameter(Mandatory = $true)][string]$SqlFile,
    [Parameter(Mandatory = $true)][string]$RunDirectory
  )
  Assert-PsqlDisposableOwnershipInvariant -State $State
  $previousOwner = [string]$State.OwnerState
  Assert-Condition -Condition ($previousOwner -cin @("none", "caller")) `
    -Code "psql_disposable_controller_ownership_rejected" -FailureClass "source_integrity_rejection"
  Assert-Condition -Condition ($previousOwner -cne "none" -or ($State.WorkerTransferCount -eq 0 -and
    $State.CleanupInvocationCount -eq 0 -and -not $State.CleanupCompleted -and -not $State.ProcessStartObserved)) `
    -Code "psql_disposable_controller_history_rejected" -FailureClass "source_integrity_rejection"
  $identity = Get-PsqlDisposableIdentity -SqlFile $SqlFile -RunDirectory $RunDirectory
  Assert-PsqlDisposableStateIdentity -State $State -Identity $identity
  $State.OwnerState = "controller"
  Assert-PsqlDisposableOwnershipInvariant -State $State
}

function Set-PsqlDisposableStarterOwnership {
  param(
    [Parameter(Mandatory = $true)][object]$State,
    [Parameter(Mandatory = $true)][object]$Process
  )
  $previous = [pscustomobject]@{
    Process = $State.Process
    ProcessStartObserved = $State.ProcessStartObserved
    ProcessId = $State.ProcessId
    ProcessIdObserved = $State.ProcessIdObserved
    OwnerState = [string]$State.OwnerState
  }
  $State.Process = $Process
  $State.ProcessStartObserved = $true
  $State.ProcessId = $null
  $State.ProcessIdObserved = $false
  $State.OwnerState = "starter"
  try {
    Assert-Condition -Condition ($previous.OwnerState -ceq "controller" -and $State.IdentityFrozen -and
      $null -eq $previous.Process -and -not $previous.ProcessStartObserved -and $null -eq $previous.ProcessId -and
      -not $previous.ProcessIdObserved -and $null -ne $Process -and $null -eq $State.Worker -and
      -not $State.CleanupCompleted) -Code "psql_disposable_starter_transfer_rejected" -FailureClass "source_integrity_rejection"
    Assert-PsqlDisposableOwnershipInvariant -State $State
  }
  catch {
    $transitionError = $_
    $State.Process = $previous.Process
    $State.ProcessStartObserved = $previous.ProcessStartObserved
    $State.ProcessId = $previous.ProcessId
    $State.ProcessIdObserved = $previous.ProcessIdObserved
    $State.OwnerState = $previous.OwnerState
    throw $transitionError
  }
}

function Assert-PsqlDisposableStarterPreconditions {
  param([Parameter(Mandatory = $true)][object]$State)
  Assert-PsqlDisposableOwnershipInvariant -State $State
  Assert-Condition -Condition ([string]$State.OwnerState -ceq "controller" -and $State.IdentityFrozen -and
    -not $State.ProcessStartObserved -and $null -eq $State.Process -and $null -eq $State.ProcessId -and
    -not $State.ProcessIdObserved) -Code "psql_disposable_starter_transfer_rejected" -FailureClass "source_integrity_rejection"
  [void](Assert-PsqlDisposableFrozenIdentity -State $State)
}

function Set-PsqlDisposableWorkerOwnership {
  param(
    [Parameter(Mandatory = $true)][object]$State,
    [Parameter(Mandatory = $true)][object]$Worker
  )
  Assert-PsqlDisposableOwnershipInvariant -State $State
  [void](Assert-PsqlDisposableFrozenIdentity -State $State)
  Assert-Condition -Condition ([string]$State.OwnerState -ceq "starter" -and $State.IdentityFrozen -and
    $State.ProcessStartObserved -and $null -ne $State.Process -and $State.ProcessIdObserved -and
    $null -ne $State.ProcessId -and [int]$State.ProcessId -gt 0 -and $null -ne $Worker) `
    -Code "psql_disposable_worker_transfer_rejected" -FailureClass "source_integrity_rejection"
  Assert-Condition -Condition ((Test-ObjectProperty -Value $Worker -Name "Process") -and
    (Test-ObjectProperty -Value $Worker -Name "SqlFile") -and
    (Test-ObjectProperty -Value $Worker -Name "RunDirectory") -and
    (Test-ObjectProperty -Value $Worker -Name "DisposableSqlOwnershipState") -and
    [object]::ReferenceEquals($State.Process, $Worker.Process) -and
    [object]::ReferenceEquals($State, $Worker.DisposableSqlOwnershipState) -and
    [string]::Equals([string]$State.CanonicalPath, [System.IO.Path]::GetFullPath([string]$Worker.SqlFile), [System.StringComparison]::OrdinalIgnoreCase) -and
    [string]::Equals([string]$State.CanonicalRunDirectory, [System.IO.Path]::GetFullPath([string]$Worker.RunDirectory).TrimEnd('\', '/'), [System.StringComparison]::OrdinalIgnoreCase)) `
    -Code "psql_disposable_worker_candidate_rejected" -FailureClass "source_integrity_rejection"
  Assert-Condition -Condition ($State.StartInfoMaterialCleared -and $null -ne $State.StartInfo -and
    -not (Test-PsqlStartInfoContainsPgMaterial -StartInfo $State.StartInfo)) `
    -Code "psql_disposable_worker_start_info_rejected" -FailureClass "postcondition_rejection"
  $workerExecutionContext = if (Test-ObjectProperty -Value $Worker -Name "ExecutionContext") { $Worker.ExecutionContext } else { $null }
  Assert-Condition -Condition ($State.LocalPidAddAttempted -and $State.LocalPidRecorded -and
    ($null -eq $workerExecutionContext -or ($State.ExecutePidAddAttempted -and $State.ExecutePidRecorded))) `
    -Code "psql_disposable_worker_pid_registration_rejected" -FailureClass "postcondition_rejection"
  Assert-Condition -Condition (-not $State.CleanupAttempted -and -not $State.CleanupCompleted -and
    $State.CleanupInvocationCount -eq 0 -and $State.WorkerTransferCount -eq 0 -and $null -eq $State.Worker) `
    -Code "psql_disposable_worker_history_rejected" -FailureClass "source_integrity_rejection"

  $previousWorker = $State.Worker
  $previousOwnerState = [string]$State.OwnerState
  $previousWorkerTransferCount = [int]$State.WorkerTransferCount
  try {
    $State.Worker = $Worker
    $State.OwnerState = "worker"
    $State.WorkerTransferCount = $previousWorkerTransferCount + 1
    if ($ValidateOnly -and $script:Db26WorkerTransferFault -ceq "post_mutation_invariant") {
      Throw-StableFailure -Code "db26_synthetic_worker_post_mutation_invariant_failure" -FailureClass "postcondition_rejection"
    }
    Assert-PsqlDisposableOwnershipInvariant -State $State
  }
  catch {
    $transitionError = $_
    $State.Worker = $previousWorker
    $State.OwnerState = $previousOwnerState
    $State.WorkerTransferCount = $previousWorkerTransferCount
    throw $transitionError
  }
}

function Complete-PsqlDisposableWorkerOwnership {
  param([Parameter(Mandatory = $true)][object]$State)
  Assert-PsqlDisposableOwnershipInvariant -State $State
  Assert-Condition -Condition ([string]$State.OwnerState -ceq "worker" -and $State.ProcessStartObserved -and
    $State.ProcessTerminationObserved) `
    -Code "psql_disposable_worker_collection_rejected" -FailureClass "postcondition_rejection"
  [void](Assert-PsqlDisposableFrozenIdentity -State $State)
  Assert-Condition -Condition (-not (Test-Path -LiteralPath $State.CanonicalPath)) `
    -Code "psql_disposable_worker_file_residue_rejected" -FailureClass "postcondition_rejection"
  $State.OwnerState = "completed"
  $State.CleanupCompleted = $true
  $State.AbsenceObserved = $true
  $State.CollectionCount = [int]$State.CollectionCount + 1
  Assert-PsqlDisposableOwnershipInvariant -State $State
}

function Assert-PsqlDisposableFrozenIdentity {
  param([Parameter(Mandatory = $true)][object]$State)
  $identity = Get-PsqlDisposableIdentity -SqlFile ([string]$State.CanonicalPath) -RunDirectory ([string]$State.CanonicalRunDirectory)
  Assert-Condition -Condition ([string]::Equals([string]$identity.CanonicalPath, [string]$State.CanonicalPath, [System.StringComparison]::OrdinalIgnoreCase) -and
    [string]::Equals([string]$identity.CanonicalRunDirectory, [string]$State.CanonicalRunDirectory, [System.StringComparison]::OrdinalIgnoreCase) -and
    [string]$identity.CanonicalFileName -ceq [string]$State.CanonicalFileName) `
    -Code "psql_disposable_frozen_identity_rejected" -FailureClass "source_integrity_rejection"
  if (Test-Path -LiteralPath $State.CanonicalPath -PathType Leaf) {
    Assert-Condition -Condition (-not [string]::IsNullOrWhiteSpace([string]$State.ExpectedSha256)) `
      -Code "psql_disposable_identity_hash_missing" -FailureClass "postcondition_rejection"
    Assert-Condition -Condition ((Get-Sha256 -Path $State.CanonicalPath) -ceq [string]$State.ExpectedSha256) `
      -Code "psql_disposable_identity_hash_mismatch" -FailureClass "postcondition_rejection"
    Assert-Condition -Condition ([long](Get-Item -LiteralPath $State.CanonicalPath -Force).Length -eq [long]$State.ExpectedByteLength) `
      -Code "psql_disposable_identity_length_mismatch" -FailureClass "postcondition_rejection"
  }
  return $identity
}

function Invoke-PsqlDisposableOwnershipCleanup {
  param(
    [Parameter(Mandatory = $true)][object]$State,
    [Parameter(Mandatory = $true)][ValidateSet("caller", "controller", "starter")][string]$RequiredOwner
  )
  Assert-PsqlDisposableOwnershipInvariant -State $State
  Assert-Condition -Condition ([string]$State.OwnerState -ceq $RequiredOwner) `
    -Code "psql_disposable_cleanup_owner_rejected" -FailureClass "postcondition_rejection"
  if ($RequiredOwner -ceq "starter") {
    Assert-Condition -Condition ($State.ProcessStartObserved -and $State.ProcessTerminationObserved -and
      $null -ne $State.Process -and $State.Process.HasExited) `
      -Code "psql_disposable_cleanup_before_termination_rejected" -FailureClass "postcondition_rejection"
  }
  $State.CleanupAttempted = $true
  $State.CleanupInvocationCount = [int]$State.CleanupInvocationCount + 1
  $cleanup = Invoke-OrchestrationCleanup -EmitFailureMarkers -CleanupOperations @(
    [pscustomobject]@{ Name = "PSQL_DISPOSABLE_PATH_GUARD"; Operation = {
      [void](Assert-PsqlDisposableFrozenIdentity -State $State)
    } },
    [pscustomobject]@{ Name = "PSQL_DISPOSABLE_PATH_REMOVE"; Operation = {
      [void](Assert-PsqlDisposableFrozenIdentity -State $State)
      $State.RemovalAttemptCount = [int]$State.RemovalAttemptCount + 1
      if ($ValidateOnly -and $script:PsqlHandoffFixtureFault -ceq "removal_failure") {
        Throw-StableFailure -Code "psql_disposable_fixture_removal_failure" -FailureClass "postcondition_rejection"
      }
      if (Test-Path -LiteralPath $State.CanonicalPath) {
        Assert-Condition -Condition (Test-Path -LiteralPath $State.CanonicalPath -PathType Leaf) `
          -Code "psql_disposable_cleanup_nonfile_rejected" -FailureClass "postcondition_rejection"
        Remove-Item -LiteralPath $State.CanonicalPath -Force
      }
    } },
    [pscustomobject]@{ Name = "PSQL_DISPOSABLE_PATH_ABSENT"; Operation = {
      [void](Assert-PsqlDisposableFrozenIdentity -State $State)
      Assert-Condition -Condition (-not (Test-Path -LiteralPath $State.CanonicalPath)) `
        -Code "psql_disposable_cleanup_absence_rejected" -FailureClass "postcondition_rejection"
    } }
  )
  $State.SecondaryCleanupErrors = @($State.SecondaryCleanupErrors) + @($cleanup.SecondaryErrors)
  if ($cleanup.Succeeded -and -not (Test-Path -LiteralPath $State.CanonicalPath)) {
    $State.OwnerState = "completed"
    $State.CleanupCompleted = $true
    $State.AbsenceObserved = $true
  }
  Assert-PsqlDisposableOwnershipInvariant -State $State
  return $cleanup
}

function Invoke-PsqlDisposableControllerCleanup {
  param([Parameter(Mandatory = $true)][object]$State)
  Assert-PsqlDisposableOwnershipInvariant -State $State
  Assert-Condition -Condition ([string]$State.OwnerState -cin @("caller", "controller")) `
    -Code "psql_disposable_controller_cleanup_owner_rejected" -FailureClass "postcondition_rejection"
  return Invoke-PsqlDisposableOwnershipCleanup -State $State -RequiredOwner ([string]$State.OwnerState)
}

function Invoke-PsqlDisposableStarterCleanup {
  param([Parameter(Mandatory = $true)][object]$State)
  return Invoke-PsqlDisposableOwnershipCleanup -State $State -RequiredOwner "starter"
}

function Invoke-PsqlFile {
  param(
    [Parameter(Mandatory = $true)][object]$Connection,
    [Parameter(Mandatory = $true)][string]$PsqlPath,
    [Parameter(Mandatory = $true)][string]$SqlFile,
    [Parameter(Mandatory = $true)][string]$ApplicationName,
    [Parameter(Mandatory = $true)][string]$RunDirectory,
    [ValidateSet("read committed", "repeatable read")][string]$DefaultIsolation = "read committed",
    [int]$StatementTimeoutMilliseconds = 90000,
    [int]$LockTimeoutMilliseconds = 30000,
    [ValidateRange(0, 600000)][int]$ProcessTimeoutMilliseconds = 0,
    [switch]$KeepRawLogs,
    [bool]$DeleteSqlFileOnCompletion = $false,
    [AllowNull()][object]$DisposableSqlOwnershipState = $null,
    [switch]$EmitSessionIsolationMarker,
    [switch]$EmitRepositoryFileCompletedMarker
  )
  $worker = $null
  $workerCollected = $false
  $ownershipState = if ($null -ne $DisposableSqlOwnershipState) {
    $DisposableSqlOwnershipState
  }
  else {
    New-PsqlDisposableOwnershipState -SqlFile $SqlFile -RunDirectory $RunDirectory
  }
  try {
    if ($DeleteSqlFileOnCompletion) {
      Assert-DisposableWorkerSqlPath -SqlFile $SqlFile -RunDirectory $RunDirectory
      if ([string]$ownershipState.OwnerState -ceq "caller") {
        Set-PsqlDisposableControllerOwnership -State $ownershipState -SqlFile $SqlFile -RunDirectory $RunDirectory
      }
      else {
        Assert-Condition -Condition ([string]$ownershipState.OwnerState -ceq "controller") `
          -Code "psql_disposable_controller_ownership_missing" -FailureClass "source_integrity_rejection"
        [void](Assert-PsqlDisposableFrozenIdentity -State $ownershipState)
      }
    }
    Assert-Condition -Condition (Test-Path -LiteralPath $SqlFile -PathType Leaf) -Code "worker_sql_file_missing"
    $effectiveProcessTimeout = Resolve-PsqlProcessTimeoutMilliseconds -StatementTimeoutMilliseconds $StatementTimeoutMilliseconds -ProcessTimeoutMilliseconds $ProcessTimeoutMilliseconds
    $worker = Start-PsqlWorker -Connection $Connection -PsqlPath $PsqlPath -SqlFile $SqlFile -ApplicationName $ApplicationName -RunDirectory $RunDirectory -DefaultIsolation $DefaultIsolation -StatementTimeoutMilliseconds $StatementTimeoutMilliseconds -LockTimeoutMilliseconds $LockTimeoutMilliseconds -DeleteSqlFileOnCompletion $DeleteSqlFileOnCompletion -DisposableSqlOwnershipState $ownershipState -EmitSessionIsolationMarker:$EmitSessionIsolationMarker -EmitRepositoryFileCompletedMarker:$EmitRepositoryFileCompletedMarker
    $result = Wait-PsqlWorker -Worker $worker -TimeoutMilliseconds $effectiveProcessTimeout -KeepRawLogs:$KeepRawLogs
    $workerCollected = $true
    return $result
  }
  catch {
    $primaryError = $_
    $primaryFailureClass = [string]$primaryError.Exception.Data["FailureClass"]
    $primaryScenario = [string]$script:CurrentScenario
    if ($null -eq $ownershipState.PrimaryErrorRecord) {
      $ownershipState.PrimaryErrorRecord = $primaryError
      $ownershipState.PrimaryFailureClass = $primaryFailureClass
      $ownershipState.PrimaryScenario = $primaryScenario
    }
    if ($null -ne $worker -and -not $workerCollected) {
      $cleanup = Invoke-OrchestrationCleanup -EmitFailureMarkers -CleanupOperations @(
        [pscustomobject]@{ Name = "PSQL_WORKER_STOP"; Operation = {
          $workerCleanup = Stop-PsqlWorker -Worker $worker
          Assert-Condition -Condition $workerCleanup.Succeeded -Code "worker_cleanup_rejected"
        } }
      )
      $ownershipState.SecondaryCleanupErrors = @($ownershipState.SecondaryCleanupErrors) + @($cleanup.SecondaryErrors)
    }
    elseif ($null -eq $worker -and $DeleteSqlFileOnCompletion -and
      [string]$ownershipState.OwnerState -ceq "worker") {
      $cleanup = Invoke-OrchestrationCleanup -EmitFailureMarkers -CleanupOperations @(
        [pscustomobject]@{ Name = "PSQL_FILE_WORKER_HANDOFF_STATE"; Operation = {
          Assert-Condition -Condition ($null -ne $ownershipState.Worker -and $null -ne $ownershipState.Process -and
            (Test-ObjectProperty -Value $ownershipState.Worker -Name "ProcessStartState") -and
            [object]::ReferenceEquals($ownershipState.Worker.ProcessStartState, $ownershipState) -and
            [object]::ReferenceEquals($ownershipState.Worker.Process, $ownershipState.Process)) `
            -Code "psql_file_worker_handoff_state_rejected" -FailureClass "postcondition_rejection"
          $workerCleanup = Stop-PsqlWorker -Worker $ownershipState.Worker
          Assert-Condition -Condition $workerCleanup.Succeeded -Code "worker_cleanup_rejected"
        } }
      )
      $ownershipState.SecondaryCleanupErrors = @($ownershipState.SecondaryCleanupErrors) + @($cleanup.SecondaryErrors)
    }
    elseif ($null -eq $worker -and $DeleteSqlFileOnCompletion -and
      [string]$ownershipState.OwnerState -cin @("caller", "controller")) {
      $cleanup = Invoke-PsqlDisposableControllerCleanup -State $ownershipState
    }
    else {
      $cleanup = [pscustomobject]@{ Succeeded = $true; SecondaryErrors = @() }
    }
    Complete-OrchestrationCleanup -PrimaryError $primaryError -PrimaryScenario $primaryScenario -CleanupResult $cleanup `
      -CleanupFailureCode "psql_disposable_cleanup_rejected"
  }
}

function Invoke-PsqlSqlOuterHandoffCleanup {
  param([Parameter(Mandatory = $true)][object]$State)
  if ([string]$State.OwnerState -ceq "completed" -and
    -not [string]::IsNullOrWhiteSpace([string]$State.CanonicalPath) -and
    (Test-Path -LiteralPath $State.CanonicalPath)) {
    Throw-StableFailure -Code "psql_handoff_completed_path_reappeared" -FailureClass "postcondition_rejection"
  }
  Assert-PsqlDisposableOwnershipInvariant -State $State
  if (-not [string]::IsNullOrWhiteSpace([string]$State.CanonicalPath) -and
    [string]$State.OwnerState -cin @("caller", "controller")) {
    return Invoke-PsqlDisposableControllerCleanup -State $State
  }
  return [pscustomobject]@{ Succeeded = $true; SecondaryErrors = @() }
}

function Invoke-PsqlSql {
  param(
    [Parameter(Mandatory = $true)][object]$Connection,
    [Parameter(Mandatory = $true)][string]$PsqlPath,
    [Parameter(Mandatory = $true)][string]$Sql,
    [Parameter(Mandatory = $true)][string]$ApplicationName,
    [Parameter(Mandatory = $true)][string]$RunDirectory,
    [ValidateSet("read committed", "repeatable read")][string]$DefaultIsolation = "read committed",
    [int]$StatementTimeoutMilliseconds = 90000,
    [int]$LockTimeoutMilliseconds = 30000,
    [ValidateRange(0, 600000)][int]$ProcessTimeoutMilliseconds = 0,
    [switch]$KeepRawLogs
  )
  $handoffState = $null
  $handoffError = $null
  $handoffScenario = $null
  try {
    $artifact = New-SqlFile -RunDirectory $RunDirectory -Label $ApplicationName.Substring("sitaa_sem01_".Length) -Sql $Sql -InitialOwner caller
    $handoffState = $artifact.OwnershipState
    if ($ValidateOnly) {
      $fixtureLeaf = Split-Path -Leaf ([System.IO.Path]::GetFullPath($RunDirectory))
      if ($fixtureLeaf -cmatch '^validate-db23-[a-f0-9]{32}$') { $script:Db23LastHandoffState = $handoffState }
      if ($fixtureLeaf -cmatch '^validate-db24-[a-f0-9]{32}$') { $script:Db24LastHandoffState = $handoffState }
    }
    if ($ValidateOnly -and $script:Db25HandoffFault -ceq "replace_before_invoke") {
      [System.IO.File]::WriteAllText($artifact.Path, "db25 replacement before caller use`n", (New-Object System.Text.UTF8Encoding($false)))
    }
    return Invoke-PsqlFile -Connection $Connection -PsqlPath $PsqlPath -SqlFile $artifact.Path -ApplicationName $ApplicationName -RunDirectory $RunDirectory -DefaultIsolation $DefaultIsolation -StatementTimeoutMilliseconds $StatementTimeoutMilliseconds -LockTimeoutMilliseconds $LockTimeoutMilliseconds -ProcessTimeoutMilliseconds $ProcessTimeoutMilliseconds -KeepRawLogs:$KeepRawLogs -DeleteSqlFileOnCompletion $true -DisposableSqlOwnershipState $artifact.OwnershipState
  }
  catch {
    $handoffError = $_
    $handoffScenario = [string]$script:CurrentScenario
    if ($null -ne $handoffState -and $null -eq $handoffState.PrimaryErrorRecord) {
      $handoffState.PrimaryErrorRecord = $handoffError
      $handoffState.PrimaryFailureClass = [string]$handoffError.Exception.Data["FailureClass"]
      $handoffState.PrimaryScenario = $handoffScenario
    }
    if ($ValidateOnly -and $script:Db25HandoffFault -ceq "recreate_completed" -and
      $null -ne $handoffState -and [string]$handoffState.OwnerState -ceq "completed") {
      [System.IO.File]::WriteAllText($handoffState.CanonicalPath, "db25 replacement after completed cleanup`n", (New-Object System.Text.UTF8Encoding($false)))
    }
  }
  $handoffCleanup = Invoke-OrchestrationCleanup -EmitFailureMarkers -CleanupOperations @(
    [pscustomobject]@{ Name = "PSQL_HANDOFF_OUTER_CLEANUP"; Operation = {
      Assert-Condition -Condition ($null -ne $handoffState) -Code "psql_handoff_state_missing" -FailureClass "postcondition_rejection"
      $outerResult = Invoke-PsqlSqlOuterHandoffCleanup -State $handoffState
      Assert-Condition -Condition $outerResult.Succeeded -Code "psql_handoff_outer_cleanup_rejected" -FailureClass "postcondition_rejection"
    } }
  )
  if ($null -ne $handoffState) {
    $handoffState.SecondaryCleanupErrors = @($handoffState.SecondaryCleanupErrors) + @($handoffCleanup.SecondaryErrors)
  }
  Complete-OrchestrationCleanup -PrimaryError $handoffError -PrimaryScenario $handoffScenario -CleanupResult $handoffCleanup `
    -CleanupFailureCode "psql_handoff_cleanup_rejected"
}

function Get-MarkerParts {
  param(
    [Parameter(Mandatory = $true)][object]$Result,
    [Parameter(Mandatory = $true)][string]$Marker
  )
  $lines = @($Result.Stdout -split "\r?\n" | Where-Object { $_.StartsWith($Marker + "|") })
  Assert-Condition -Condition ($lines.Count -eq 1) -Code "database_marker_rejected"
  return @($lines[0].Split('|'))
}

function Get-ExactSessionDefaultIsolation {
  param([Parameter(Mandatory = $true)][object]$Result)
  $markerPrefix = "SESSION_DEFAULT_ISOLATION|"
  $lines = @($Result.Stdout -split "\r?\n" | Where-Object { $_.StartsWith($markerPrefix, [System.StringComparison]::Ordinal) })
  Assert-Condition -Condition ($lines.Count -eq 1) -Code "session_default_isolation_marker_rejected" -FailureClass "source_integrity_rejection"
  Assert-Condition -Condition ($lines[0] -ceq "SESSION_DEFAULT_ISOLATION|repeatable read") -Code "session_default_isolation_value_rejected" -FailureClass "source_integrity_rejection"
  return "repeatable read"
}

function Get-ExactRepositoryFileCompletedMarker {
  param([Parameter(Mandatory = $true)][object]$Result)
  $lines = @($Result.Stdout -split "\r?\n" | Where-Object { $_ -ceq "REPOSITORY_FILE_COMPLETED|1" })
  Assert-Condition -Condition ($lines.Count -eq 1) -Code "repository_file_completed_marker_rejected" -FailureClass "source_integrity_rejection"
  return $true
}

function Get-DatabasePhaseSql {
  return @'
begin;
set transaction isolation level read committed;
set transaction read only;
with presence as (
  select
    (to_regclass('public.academic_period_audit_events') is not null)::int audit_table,
    (to_regprocedure('public.list_admin_academic_periods(integer,integer)') is not null)::int list_rpc,
    (to_regprocedure('public.acquire_sem01_calendar_lock_0011()') is not null)::int lock_helper,
    (to_regprocedure('public.create_admin_academic_period(text,date,date,boolean)') is not null)::int create_rpc,
    (to_regprocedure('public.correct_admin_academic_period(uuid,text,date,date,text)') is not null)::int correct_rpc,
    (to_regprocedure('public.activate_admin_academic_period(uuid,text)') is not null)::int activate_rpc,
    (to_regprocedure('public.deactivate_admin_academic_period(uuid,text)') is not null)::int deactivate_rpc,
    (select (count(*) = 1)::int from pg_catalog.pg_trigger where tgrelid = 'public.activities'::regclass and tgname = 'activities_sem01_lock_insert' and not tgisinternal) activity_insert_trigger,
    (select (count(*) = 1)::int from pg_catalog.pg_trigger where tgrelid = 'public.activities'::regclass and tgname = 'activities_sem01_lock_update' and not tgisinternal) activity_update_trigger,
    (select (count(*) = 1)::int from pg_catalog.pg_trigger where tgrelid = 'public.academic_periods'::regclass and tgname = 'academic_periods_guard_sem01' and not tgisinternal) period_guard_trigger,
    (select (count(*) = 1)::int from pg_catalog.pg_trigger where tgrelid = 'public.academic_periods'::regclass and tgname = 'academic_periods_guard_truncate_sem01' and not tgisinternal) period_truncate_trigger,
    (select (count(*) = 1)::int from pg_catalog.pg_trigger where tgrelid = 'public.academic_periods'::regclass and tgname = 'academic_periods_set_updated_at_sem01' and not tgisinternal) period_updated_trigger,
    (select (count(*) = 1)::int from pg_catalog.pg_trigger where tgrelid = to_regclass('public.academic_period_audit_events') and tgname = 'academic_period_audit_events_guard_update_delete' and not tgisinternal) audit_guard_trigger,
    (select (count(*) = 1)::int from pg_catalog.pg_trigger where tgrelid = to_regclass('public.academic_period_audit_events') and tgname = 'academic_period_audit_events_guard_truncate' and not tgisinternal) audit_truncate_trigger,
    (select (count(*) = 1)::int from pg_catalog.pg_constraint where conname = 'academic_periods_sem01_shape_check' and conrelid = 'public.academic_periods'::regclass) period_shape_constraint,
    (select (count(*) = 1)::int from pg_catalog.pg_constraint where conname = 'academic_periods_active_date_range_excl' and conrelid = 'public.academic_periods'::regclass) period_exclusion_constraint
), classified as (
  select *, case
    when audit_table + list_rpc + lock_helper + create_rpc + correct_rpc + activate_rpc + deactivate_rpc +
      activity_insert_trigger + activity_update_trigger + period_guard_trigger + period_truncate_trigger +
      period_updated_trigger + audit_guard_trigger + audit_truncate_trigger + period_shape_constraint + period_exclusion_constraint = 0 then 'POST0010'
    when audit_table + list_rpc + lock_helper + create_rpc + correct_rpc + activate_rpc + deactivate_rpc +
      activity_insert_trigger + activity_update_trigger + period_guard_trigger + period_truncate_trigger +
      period_updated_trigger + audit_guard_trigger + audit_truncate_trigger + period_shape_constraint + period_exclusion_constraint = 16 then 'POST0011'
    else 'UNKNOWN'
  end database_state
  from presence
)
select 'DB_PHASE|' || database_state || '|' || audit_table || '|' || list_rpc || '|' || lock_helper || '|' ||
  list_rpc || '|' || create_rpc || '|' || correct_rpc || '|' || activate_rpc || '|' || deactivate_rpc || '|' ||
  activity_insert_trigger || '|' || activity_update_trigger || '|' || period_guard_trigger || '|' || period_truncate_trigger || '|' ||
  period_updated_trigger || '|' || audit_guard_trigger || '|' || audit_truncate_trigger || '|' ||
  period_shape_constraint || '|' || period_exclusion_constraint
from classified;
rollback;
'@
}

function Invoke-ReadOnlyDatabaseDiagnostic {
  param(
    [Parameter(Mandatory = $true)][object]$Connection,
    [Parameter(Mandatory = $true)][string]$PsqlPath,
    [Parameter(Mandatory = $true)][string]$RunDirectory
  )
  $phaseResult = Invoke-PsqlSql -Connection $Connection -PsqlPath $PsqlPath -Sql (Get-DatabasePhaseSql) -ApplicationName "sitaa_sem01_phase_diagnostic" -RunDirectory $RunDirectory
  Assert-PsqlApproved -Result $phaseResult -FailureCode "database_phase_probe_failed"
  $phaseParts = Get-MarkerParts -Result $phaseResult -Marker "DB_PHASE"
  Assert-Condition -Condition ($phaseParts.Count -eq 19 -and $phaseParts[1] -in @("POST0010", "POST0011", "UNKNOWN")) -Code "database_phase_diagnostic_shape_rejected"

  $countsSql = @"
begin;
set transaction isolation level read committed;
set transaction read only;
select 'DIAGNOSTIC_COUNTS|' ||
  (select count(*) from public.academic_periods)::text || '|' ||
  (select count(*) from public.activities)::text || '|' ||
  (select count(*) from public.academic_periods where code in ('2098-1', '2098-2', '2099-1', '2099-2'))::text || '|' ||
  (select count(*) from pg_catalog.pg_locks lock where lock.locktype = 'advisory' and lock.classid = $($script:Sem01AdvisoryKeyOne) and lock.objid = $($script:Sem01AdvisoryKeyTwo) and lock.objsubid = $($script:Sem01AdvisoryObjSubId) and lock.granted)::text || '|' ||
  (select count(*) from pg_catalog.pg_locks lock where lock.locktype = 'advisory' and lock.classid = $($script:Sem01AdvisoryKeyOne) and lock.objid = $($script:Sem01AdvisoryKeyTwo) and lock.objsubid = $($script:Sem01AdvisoryObjSubId) and not lock.granted)::text || '|' ||
  (select count(*) from pg_catalog.pg_locks lock where lock.locktype = 'advisory' and lock.classid = $($script:Sem01AdvisoryKeyOne) and lock.objid = $($script:Sem01AdvisoryKeyTwo) and lock.objsubid = $($script:Sem01AdvisoryObjSubId))::text || '|' ||
  (select count(*) from pg_catalog.pg_stat_activity activity where activity.pid <> pg_backend_pid() and activity.application_name like 'sitaa_sem01_%')::text || '|' ||
  (select count(*) from pg_catalog.pg_class relation join pg_catalog.pg_namespace namespace on namespace.oid = relation.relnamespace where namespace.nspname like 'sitaa_sem01_%')::text;
rollback;
"@
  $countsResult = Invoke-PsqlSql -Connection $Connection -PsqlPath $PsqlPath -Sql $countsSql -ApplicationName "sitaa_sem01_count_diagnostic" -RunDirectory $RunDirectory
  Assert-PsqlApproved -Result $countsResult -FailureCode "database_diagnostic_count_probe_failed"
  $countParts = Get-MarkerParts -Result $countsResult -Marker "DIAGNOSTIC_COUNTS"
  Assert-Condition -Condition ($countParts.Count -eq 9) -Code "database_diagnostic_count_shape_rejected"

  $auditEvents = 0
  if ([int]$phaseParts[2] -eq 1) {
    $auditSql = "begin; set transaction isolation level read committed; set transaction read only; select 'DIAGNOSTIC_AUDIT|' || count(*) from public.academic_period_audit_events; rollback;"
    $auditResult = Invoke-PsqlSql -Connection $Connection -PsqlPath $PsqlPath -Sql $auditSql -ApplicationName "sitaa_sem01_audit_diagnostic" -RunDirectory $RunDirectory
    Assert-PsqlApproved -Result $auditResult -FailureCode "database_diagnostic_audit_probe_failed"
    $auditEvents = [int](Get-MarkerParts -Result $auditResult -Marker "DIAGNOSTIC_AUDIT")[1]
  }

  return [pscustomobject]@{
    DatabaseState = [string]$phaseParts[1]
    FingerprintAvailable = $false
    PartialStateReason = $(if ([string]$phaseParts[1] -ceq "UNKNOWN") { "incomplete_0011_inventory" } else { $null })
    AuditTablePresent = ([int]$phaseParts[2] -eq 1)
    AdminListPresent = ([int]$phaseParts[3] -eq 1)
    CalendarLockHelperPresent = ([int]$phaseParts[4] -eq 1)
    PeriodRpcPresence = @($phaseParts[5..9] | ForEach-Object { [int]$_ })
    TriggerPresence = @($phaseParts[10..16] | ForEach-Object { [int]$_ })
    ConstraintPresence = @($phaseParts[17..18] | ForEach-Object { [int]$_ })
    Periods = [int]$countParts[1]
    Activities = [int]$countParts[2]
    FixturePeriods = [int]$countParts[3]
    GrantedSem01AdvisoryLocks = [int]$countParts[4]
    WaitingSem01AdvisoryLocks = [int]$countParts[5]
    TotalSem01AdvisoryLocks = [int]$countParts[6]
    OpenWorkers = [int]$countParts[7]
    TransientWorkerSqlFiles = Get-TransientWorkerSqlFileCount -RunDirectory $RunDirectory
    TemporaryObjects = [int]$countParts[8]
    AuditEvents = $auditEvents
    State = $null
    PeriodHash = $null
    PeriodIdentityHash = $null
    ExactAuthorities = $null
    SyntheticAuthorities = $null
    AuthorityHash = $null
    AssignmentHash = $null
    Ms20CandidateCount = $null
    Ms20CandidateSetHash = $null
    ResolverHash = $null
    BoundaryContractHash = $null
    FunctionInventoryCount = $null
    FunctionInventoryHash = $null
    FunctionInventoryValid = $null
    ExpectedTriggerMatchCount = $null
    TriggerInventoryHash = $null
    TriggerInventoryValid = $null
    ConstraintInventoryHash = $null
    AuditConstraintCount = $null
    AuditConstraintInventoryValid = $null
    IndexInventoryHash = $null
    TableSecurityHash = $null
    TableSecurityValid = $null
    RoutineAclHash = $null
    RoutineAclValid = $null
    NonexistentHelperCount = $null
    CalendarLockHelperCount = $null
    AuditTable = $null
    AdminList = $null
    CompleteTriggerInventoryValid = $null
    ActivitiesConstraintInventoryValid = $null
    PeriodConstraintInventoryValid = $null
    CompleteAuditConstraintInventoryValid = $null
    CompleteIndexInventoryValid = $null
    TableAclContractValid = $null
    RlsContractValid = $null
    PolicyContractValid = $null
  }
}

function Get-Ms20CandidateSetSql {
  return @'
select profile.id
from public.profiles profile
where profile.account_status = 'active'
  and profile.is_active
  and profile.email like '%@example.invalid'
  and not exists (
    select 1
    from public.role_assignments assignment
    where assignment.user_id = profile.id
      and assignment.role_code = 'technical_admin'
      and assignment.scope_type = 'system'
      and assignment.service_area = 'technical'
      and assignment.program_id is null
      and assignment.division_id is null
  )
'@
}

function Select-DeterministicMs20CandidateId {
  param([Parameter(Mandatory = $true)][string[]]$CandidateIds)
  Assert-Condition -Condition ($CandidateIds.Count -ge 1) -Code "ms20_candidate_selection_empty"
  foreach ($candidateId in $CandidateIds) {
    Assert-Condition -Condition ($candidateId -cmatch '^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$') `
      -Code "ms20_candidate_selection_id_rejected" -FailureClass "source_integrity_rejection"
  }
  return @($CandidateIds | Sort-Object)[0]
}

function Assert-Ms20CandidateSetState {
  param([Parameter(Mandatory = $true)][object]$State)
  Assert-Condition -Condition ($State.CandidateCount -ge 1) -Code "ms20_candidate_missing"
  Assert-Condition -Condition (Test-LowercaseMd5 -Value $State.CandidateSetHash) -Code "ms20_candidate_set_hash_rejected"
  Assert-Condition -Condition ($State.SelectedCandidateCount -eq 1 -and
    [string]$State.SelectedCandidateId -cmatch '^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$') `
    -Code "ms20_deterministic_candidate_rejected"
  Assert-Condition -Condition ($State.CandidatesAllSynthetic -and $State.CandidatesExcludeExactActiveAdmins) `
    -Code "ms20_candidate_eligibility_rejected"
  return $State
}

function Test-Ms20CandidateSetMatchesFrozen {
  param(
    [Parameter(Mandatory = $true)][object]$State,
    [Parameter(Mandatory = $true)][object]$FrozenFingerprint
  )
  return ($State.CandidateCount -eq $FrozenFingerprint.Ms20CandidateCount -and
    [string]$State.CandidateSetHash -ceq [string]$FrozenFingerprint.Ms20CandidateSetHash)
}

function Invoke-Ms20CandidateSetProbe {
  param(
    [Parameter(Mandatory = $true)][object]$Connection,
    [Parameter(Mandatory = $true)][string]$PsqlPath,
    [Parameter(Mandatory = $true)][string]$RunDirectory,
    [Parameter(Mandatory = $true)][string]$Label
  )
  Assert-Condition -Condition ($Label -cmatch '^[a-z0-9_]{1,48}$') -Code "ms20_candidate_probe_label_rejected" -FailureClass "source_integrity_rejection"
  $candidateSetSql = Get-Ms20CandidateSetSql
  $sql = @"
begin;
set transaction read only;
with ms20_candidates as (
$candidateSetSql
), selected_ms20_candidate as (
  select candidate.id
  from ms20_candidates candidate
  order by candidate.id
  limit 1
), exact_active_admins as (
  select distinct assignment.user_id
  from public.role_assignments assignment
  join public.profiles profile on profile.id = assignment.user_id
  where assignment.role_code = 'technical_admin'
    and assignment.scope_type = 'system'
    and assignment.service_area = 'technical'
    and assignment.program_id is null
    and assignment.division_id is null
    and assignment.is_active
    and (assignment.starts_at is null or assignment.starts_at <= (now() at time zone 'America/Mexico_City')::date)
    and (assignment.ends_at is null or assignment.ends_at >= (now() at time zone 'America/Mexico_City')::date)
    and profile.account_status = 'active'
    and profile.is_active
), candidate_state as (
  select
    (select count(*) from ms20_candidates) as candidate_count,
    (select coalesce(md5(string_agg(candidate.id::text, E'\n' order by candidate.id)), md5('')) from ms20_candidates candidate) as candidate_set_hash,
    (select count(*) from selected_ms20_candidate) as selected_candidate_count,
    (select candidate.id from selected_ms20_candidate candidate) as selected_candidate_id,
    not exists (
      select 1 from ms20_candidates candidate
      join public.profiles profile on profile.id = candidate.id
      where profile.email not like '%@example.invalid'
    ) as candidates_all_synthetic,
    not exists (
      select 1 from ms20_candidates candidate
      join exact_active_admins admin on admin.user_id = candidate.id
    ) as candidates_exclude_exact_active_admins
)
select 'MS20_CANDIDATE_STATE|' || candidate_count || '|' || candidate_set_hash || '|' || selected_candidate_count || '|' ||
  coalesce(selected_candidate_id::text, '<none>') || '|' || candidates_all_synthetic::int || '|' || candidates_exclude_exact_active_admins::int
from candidate_state;
rollback;
"@
  $result = Invoke-PsqlSql -Connection $Connection -PsqlPath $PsqlPath -Sql $sql -ApplicationName ("sitaa_sem01_" + $Label) `
    -RunDirectory $RunDirectory -KeepRawLogs
  Assert-PsqlApproved -Result $result -FailureCode "ms20_candidate_probe_rejected"
  $parts = Get-MarkerParts -Result $result -Marker "MS20_CANDIDATE_STATE"
  Assert-Condition -Condition ($parts.Count -eq 7) -Code "ms20_candidate_probe_shape_rejected"
  return Assert-Ms20CandidateSetState -State ([pscustomobject]@{
    CandidateCount = [int]$parts[1]
    CandidateSetHash = [string]$parts[2]
    SelectedCandidateCount = [int]$parts[3]
    SelectedCandidateId = [string]$parts[4]
    CandidatesAllSynthetic = ([int]$parts[5] -eq 1)
    CandidatesExcludeExactActiveAdmins = ([int]$parts[6] -eq 1)
  })
}

function Get-BaselineProbeSql {
  param([Parameter(Mandatory = $true)][ValidateSet("POST0010", "POST0011")][string]$ExpectedState)
  $auditCountSql = if ($ExpectedState -eq "POST0011") { "(select count(*) from public.academic_period_audit_events)" } else { "0::bigint" }
  $ms20CandidateSetSql = Get-Ms20CandidateSetSql
  return @"
begin;
set transaction isolation level read committed;
set transaction read only;
with exact_admins as (
  select distinct assignment.user_id
  from public.role_assignments assignment
  join public.profiles profile on profile.id = assignment.user_id
  where assignment.role_code = 'technical_admin'
    and assignment.scope_type = 'system'
    and assignment.service_area = 'technical'
    and assignment.program_id is null
    and assignment.division_id is null
    and assignment.is_active
    and (assignment.starts_at is null or assignment.starts_at <= (now() at time zone 'America/Mexico_City')::date)
    and (assignment.ends_at is null or assignment.ends_at >= (now() at time zone 'America/Mexico_City')::date)
    and profile.account_status = 'active'
    and profile.is_active
), expected_functions(signature) as (
  values
    ('public.is_exact_sem01_period_admin_0011(uuid)'),
    ('public.lock_and_reauthorize_sem01_admin_0011(uuid)'),
    ('public.normalize_sem01_reason_0011(text)'),
    ('public.is_sem01_audit_payload_valid_0011(text,text[],jsonb,jsonb)'),
    ('public.resolve_academic_period_proposal_0011(date,text,uuid,text,text,date,date,boolean)'),
    ('public.diagnose_academic_period_impact_0011(text,uuid,text,text,date,date,boolean)'),
    ('public.acquire_sem01_calendar_lock_0011()'),
    ('public.guard_academic_periods_sem01_0011()'),
    ('public.set_academic_period_updated_at_0011()'),
    ('public.guard_academic_period_audit_append_only_0011()'),
    ('public.get_academic_period_for_date(date)'),
    ('public.publish_activity(uuid)'),
    ('public.validate_activity_scheduled_state()'),
    ('public.list_admin_academic_periods(integer,integer)'),
    ('public.create_admin_academic_period(text,date,date,boolean)'),
    ('public.correct_admin_academic_period(uuid,text,date,date,text)'),
    ('public.activate_admin_academic_period(uuid,text)'),
    ('public.deactivate_admin_academic_period(uuid,text)')
), post0010_functions(signature) as (
  values
    ('public.get_academic_period_for_date(date)'),
    ('public.publish_activity(uuid)'),
    ('public.validate_activity_scheduled_state()')
), selected_functions as (
  select
    expected.signature,
    procedure_info.oid,
    procedure_info.proowner,
    pg_catalog.pg_get_userbyid(procedure_info.proowner) as owner_name,
    language_info.lanname as language_name,
    procedure_info.provolatile::text as volatility,
    procedure_info.proparallel::text as parallel_class,
    procedure_info.prosecdef,
    coalesce(procedure_info.proconfig::text, '<null>') as proconfig_text,
    coalesce(procedure_info.proacl::text, '<null>') as explicit_acl,
    case
      when right(replace(replace(pg_catalog.pg_get_functiondef(procedure_info.oid), E'\r\n', E'\n'), E'\r', E'\n'), 1) = E'\n'
      then left(
        replace(replace(pg_catalog.pg_get_functiondef(procedure_info.oid), E'\r\n', E'\n'), E'\r', E'\n'),
        length(replace(replace(pg_catalog.pg_get_functiondef(procedure_info.oid), E'\r\n', E'\n'), E'\r', E'\n')) - 1
      )
      else replace(replace(pg_catalog.pg_get_functiondef(procedure_info.oid), E'\r\n', E'\n'), E'\r', E'\n')
    end as normalized_definition
  from expected_functions expected
  join pg_catalog.pg_proc procedure_info
    on procedure_info.oid = to_regprocedure(expected.signature)
  join pg_catalog.pg_language language_info on language_info.oid = procedure_info.prolang
), function_rows as (
  select 'function|' || signature || '|owner=' || owner_name || '|language=' || language_name ||
    '|volatility=' || volatility || '|parallel=' || parallel_class || '|security_definer=' || prosecdef::text ||
    '|proconfig=' || proconfig_text || '|acl=' || explicit_acl || '|definition=' || normalized_definition as value
  from selected_functions
), expected_post0010_triggers(relation_name, trigger_name, trigger_definition, enabled_state) as (
  values
    ('activities', 'enforce_activity_writer_integrity_b2a', 'CREATE TRIGGER enforce_activity_writer_integrity_b2a BEFORE INSERT OR UPDATE ON activities FOR EACH ROW EXECUTE FUNCTION enforce_activity_writer_integrity_b2a()', 'O'),
    ('activities', 'set_activities_updated_at', 'CREATE TRIGGER set_activities_updated_at BEFORE UPDATE ON activities FOR EACH ROW EXECUTE FUNCTION set_updated_at()', 'O'),
    ('activities', 'validate_activities_scheduled_state', 'CREATE TRIGGER validate_activities_scheduled_state BEFORE INSERT OR UPDATE ON activities FOR EACH ROW EXECUTE FUNCTION validate_activity_scheduled_state()', 'O')
), expected_post0011_triggers(relation_name, trigger_name, trigger_definition, enabled_state) as (
  select * from expected_post0010_triggers
  union all values
    ('activities', 'activities_sem01_lock_insert', 'CREATE TRIGGER activities_sem01_lock_insert BEFORE INSERT ON activities FOR EACH STATEMENT EXECUTE FUNCTION acquire_sem01_calendar_lock_0011()', 'O'),
    ('activities', 'activities_sem01_lock_update', 'CREATE TRIGGER activities_sem01_lock_update BEFORE UPDATE OF start_date, status_code, academic_period_id ON activities FOR EACH STATEMENT EXECUTE FUNCTION acquire_sem01_calendar_lock_0011()', 'O'),
    ('academic_periods', 'academic_periods_guard_sem01', 'CREATE TRIGGER academic_periods_guard_sem01 BEFORE INSERT OR DELETE OR UPDATE ON academic_periods FOR EACH ROW EXECUTE FUNCTION guard_academic_periods_sem01_0011()', 'O'),
    ('academic_periods', 'academic_periods_guard_truncate_sem01', 'CREATE TRIGGER academic_periods_guard_truncate_sem01 BEFORE TRUNCATE ON academic_periods FOR EACH STATEMENT EXECUTE FUNCTION guard_academic_periods_sem01_0011()', 'O'),
    ('academic_periods', 'academic_periods_set_updated_at_sem01', 'CREATE TRIGGER academic_periods_set_updated_at_sem01 BEFORE UPDATE ON academic_periods FOR EACH ROW EXECUTE FUNCTION set_academic_period_updated_at_0011()', 'O'),
    ('academic_period_audit_events', 'academic_period_audit_events_guard_update_delete', 'CREATE TRIGGER academic_period_audit_events_guard_update_delete BEFORE DELETE OR UPDATE ON academic_period_audit_events FOR EACH ROW EXECUTE FUNCTION guard_academic_period_audit_append_only_0011()', 'O'),
    ('academic_period_audit_events', 'academic_period_audit_events_guard_truncate', 'CREATE TRIGGER academic_period_audit_events_guard_truncate BEFORE TRUNCATE ON academic_period_audit_events FOR EACH STATEMENT EXECUTE FUNCTION guard_academic_period_audit_append_only_0011()', 'O')
), trigger_rows as (
  select 'trigger|' || relation_info.relname || '|' || trigger_info.tgname || '|enabled=' || trigger_info.tgenabled::text || '|' || pg_catalog.pg_get_triggerdef(trigger_info.oid, true) as value,
    relation_info.relname, trigger_info.tgname, pg_catalog.pg_get_triggerdef(trigger_info.oid, true) trigger_definition, trigger_info.tgenabled::text enabled_state
  from pg_catalog.pg_trigger trigger_info
  join pg_catalog.pg_class relation_info on relation_info.oid = trigger_info.tgrelid
  join pg_catalog.pg_namespace namespace_info on namespace_info.oid = relation_info.relnamespace
  where namespace_info.nspname = 'public'
    and relation_info.relname in ('activities', 'academic_periods', 'academic_period_audit_events')
    and not trigger_info.tgisinternal
), expected_activities_constraints(constraint_name, constraint_definition) as (
  values
    ('activities_academic_period_id_fkey', 'FOREIGN KEY (academic_period_id) REFERENCES academic_periods(id)'),
    ('activities_activity_type_code_fkey', 'FOREIGN KEY (activity_type_code) REFERENCES activity_types(code)'),
    ('activities_attention_category_code_fkey', 'FOREIGN KEY (attention_category_code) REFERENCES attention_categories(code)'),
    ('activities_created_by_fkey', 'FOREIGN KEY (created_by) REFERENCES auth.users(id)'),
    ('activities_division_id_fkey', 'FOREIGN KEY (division_id) REFERENCES divisions(id)'),
    ('activities_duration_mode_check', 'CHECK (duration_mode IS NULL OR (duration_mode = ANY (ARRAY[''one_hour''::text, ''two_hours''::text, ''custom''::text])))'),
    ('activities_location_type_code_fkey', 'FOREIGN KEY (location_type_code) REFERENCES location_types(code)'),
    ('activities_modality_code_fkey', 'FOREIGN KEY (modality_code) REFERENCES activity_modalities(code)'),
    ('activities_pkey', 'PRIMARY KEY (id)'),
    ('activities_program_id_fkey', 'FOREIGN KEY (program_id) REFERENCES academic_programs(id)'),
    ('activities_responsible_profile_id_fkey', 'FOREIGN KEY (responsible_profile_id) REFERENCES profiles(id)'),
    ('activities_scope_consistency_check', 'CHECK (scope_type = ''program''::text AND program_id IS NOT NULL AND division_id IS NOT NULL OR scope_type = ''division''::text AND division_id IS NOT NULL AND program_id IS NULL)'),
    ('activities_scope_type_check', 'CHECK (scope_type = ANY (ARRAY[''program''::text, ''division''::text]))'),
    ('activities_service_type_code_fkey', 'FOREIGN KEY (service_type_code) REFERENCES service_types(code)'),
    ('activities_status_code_fkey', 'FOREIGN KEY (status_code) REFERENCES activity_statuses(code)'),
    ('activities_time_order_check', 'CHECK (starts_at IS NULL OR ends_at IS NULL OR ends_at > starts_at)'),
    ('activities_updated_by_fkey', 'FOREIGN KEY (updated_by) REFERENCES auth.users(id)')
), expected_period_constraints_post0010(constraint_name, constraint_definition) as (
  values
    ('academic_periods_pkey', 'PRIMARY KEY (id)'),
    ('academic_periods_code_key', 'UNIQUE (code)')
), expected_period_constraints_post0011(constraint_name, constraint_definition) as (
  select * from expected_period_constraints_post0010
  union all values
    ('academic_periods_sem01_shape_check', 'CHECK (code = ''pilot''::text AND name = ''Periodo piloto''::text AND starts_on IS NULL AND ends_on IS NULL AND NOT is_active AND sort_order = 0 OR code ~ ''^[0-9]{4}-[12]$''::text AND name IS NOT NULL AND char_length(name) >= 1 AND char_length(name) <= 120 AND name = regexp_replace(btrim(name), ''[[:space:]]+''::text, '' ''::text, ''g''::text) AND name !~ ''[[:cntrl:]]''::text AND starts_on IS NOT NULL AND ends_on IS NOT NULL AND starts_on <= ends_on)'),
    ('academic_periods_active_date_range_excl', 'EXCLUDE USING gist (daterange(starts_on, ends_on, ''[]''::text) WITH &&) WHERE ((is_active AND (code <> ''pilot''::text)))')
), expected_audit_constraints(constraint_name, constraint_definition) as (
  values
    ('academic_period_audit_events_pkey', 'PRIMARY KEY (id)'),
    ('academic_period_audit_events_actor_fkey', 'FOREIGN KEY (actor_profile_id) REFERENCES profiles(id) ON UPDATE RESTRICT ON DELETE RESTRICT'),
    ('academic_period_audit_events_period_fkey', 'FOREIGN KEY (academic_period_id) REFERENCES academic_periods(id) ON UPDATE RESTRICT ON DELETE RESTRICT'),
    ('academic_period_audit_events_code_check', 'CHECK (period_code ~ ''^[0-9]{4}-[12]$''::text)'),
    ('academic_period_audit_events_outcome_check', 'CHECK (outcome = ''success''::text)'),
    ('academic_period_audit_events_reason_check', 'CHECK (action_code = ''academic_period_created''::text AND reason IS NULL OR action_code <> ''academic_period_created''::text AND reason IS NOT NULL AND char_length(reason) >= 10 AND char_length(reason) <= 1000 AND reason = regexp_replace(btrim(reason), ''[[:space:]]+''::text, '' ''::text, ''g''::text) AND reason !~ ''[[:cntrl:]]''::text AND reason !~* ''(authorization|bearer|cookie|password|contraseña|secret|token|session|sesión|credential|credencial)''::text)'),
    ('academic_period_audit_events_payload_check', 'CHECK (is_sem01_audit_payload_valid_0011(action_code, changed_fields, old_values, new_values))')
), constraint_rows as (
  select 'constraint|' || relation_info.relname || '|' || constraint_info.conname || '|validated=' || constraint_info.convalidated::text ||
    '|deferrable=' || constraint_info.condeferrable::text || '|initially_deferred=' || constraint_info.condeferred::text || '|' ||
    pg_catalog.pg_get_constraintdef(constraint_info.oid, true) as value,
    relation_info.relname,
    constraint_info.conname,
    pg_catalog.pg_get_constraintdef(constraint_info.oid, true) constraint_definition,
    constraint_info.convalidated,
    constraint_info.condeferrable,
    constraint_info.condeferred
  from pg_catalog.pg_constraint constraint_info
  join pg_catalog.pg_class relation_info on relation_info.oid = constraint_info.conrelid
  join pg_catalog.pg_namespace namespace_info on namespace_info.oid = relation_info.relnamespace
  where namespace_info.nspname = 'public'
    and relation_info.relname in ('activities', 'academic_periods', 'academic_period_audit_events')
), expected_period_indexes_post0010(index_name, index_definition) as (
  values
    ('academic_periods_code_key', 'CREATE UNIQUE INDEX academic_periods_code_key ON public.academic_periods USING btree (code)'),
    ('academic_periods_pkey', 'CREATE UNIQUE INDEX academic_periods_pkey ON public.academic_periods USING btree (id)')
), expected_period_indexes_post0011(index_name, index_definition) as (
  values
    ('academic_periods_code_key', 'CREATE UNIQUE INDEX academic_periods_code_key ON public.academic_periods USING btree (code)'),
    ('academic_periods_pkey', 'CREATE UNIQUE INDEX academic_periods_pkey ON public.academic_periods USING btree (id)'),
    ('academic_periods_active_date_range_excl', 'CREATE INDEX academic_periods_active_date_range_excl ON public.academic_periods USING gist (daterange(starts_on, ends_on, ''[]''::text)) WHERE ((is_active AND (code <> ''pilot''::text)))')
), expected_audit_indexes(index_name, index_definition) as (
  values
    ('academic_period_audit_events_pkey', 'CREATE UNIQUE INDEX academic_period_audit_events_pkey ON public.academic_period_audit_events USING btree (id)'),
    ('academic_period_audit_events_period_occurred_idx', 'CREATE INDEX academic_period_audit_events_period_occurred_idx ON public.academic_period_audit_events USING btree (academic_period_id, occurred_at DESC, id DESC)'),
    ('academic_period_audit_events_actor_occurred_idx', 'CREATE INDEX academic_period_audit_events_actor_occurred_idx ON public.academic_period_audit_events USING btree (actor_profile_id, occurred_at DESC, id DESC)')
), index_rows as (
  select 'index|' || table_info.relname || '|' || index_info.relname || '|' || pg_catalog.pg_get_indexdef(index_info.oid) as value,
    table_info.relname, index_info.relname index_name, pg_catalog.pg_get_indexdef(index_info.oid) index_definition
  from pg_catalog.pg_index catalog_index
  join pg_catalog.pg_class index_info on index_info.oid = catalog_index.indexrelid
  join pg_catalog.pg_class table_info on table_info.oid = catalog_index.indrelid
  join pg_catalog.pg_namespace namespace_info on namespace_info.oid = table_info.relnamespace
  where namespace_info.nspname = 'public'
    and table_info.relname in ('academic_periods', 'academic_period_audit_events')
), table_security_rows as (
  select 'table_security|' || relation_info.relname || '|acl=' || coalesce(relation_info.relacl::text, '<null>') ||
    '|rls=' || relation_info.relrowsecurity::text || '|force_rls=' || relation_info.relforcerowsecurity::text as value,
    relation_info.relname,
    relation_info.relrowsecurity,
    relation_info.relforcerowsecurity
  from pg_catalog.pg_class relation_info
  join pg_catalog.pg_namespace namespace_info on namespace_info.oid = relation_info.relnamespace
  where namespace_info.nspname = 'public'
    and relation_info.relname in ('activities', 'academic_periods', 'academic_period_audit_events')
), policy_rows as (
  select relation_info.relname,
    policy_info.polname,
    policy_info.polpermissive,
    policy_info.polcmd::text command_code,
    array(select pg_catalog.pg_get_userbyid(role_oid) from unnest(policy_info.polroles) role_oid order by pg_catalog.pg_get_userbyid(role_oid) collate "C")::text role_names,
    coalesce(pg_catalog.pg_get_expr(policy_info.polqual, policy_info.polrelid), '<null>') using_expression,
    coalesce(pg_catalog.pg_get_expr(policy_info.polwithcheck, policy_info.polrelid), '<null>') check_expression
  from pg_catalog.pg_policy policy_info
  join pg_catalog.pg_class relation_info on relation_info.oid = policy_info.polrelid
  join pg_catalog.pg_namespace namespace_info on namespace_info.oid = relation_info.relnamespace
  where namespace_info.nspname = 'public'
    and relation_info.relname in ('activities', 'academic_periods', 'academic_period_audit_events')
), expected_activity_policies(policy_name, permissive, command_code, role_names, using_expression, check_expression) as (
  values
    ('Active accounts may operate activities', false, '*', '{authenticated}', 'is_sitaa_operational_account_active()', 'is_sitaa_operational_account_active()'),
    ('Authorized users can create activities', true, 'a', '{authenticated}', '<null>', '((created_by = auth.uid()) AND can_create_activity(scope_type, program_id, division_id, service_type_code))'),
    ('Authorized users can delete activities', true, 'd', '{authenticated}', 'can_delete_activity(id)', '<null>'),
    ('Authorized users can update activities', true, 'w', '{authenticated}', 'can_update_activity_base(id)', 'can_update_activity_base(id)'),
    ('Users can read permitted activities', true, 'r', '{authenticated}', '(((status_code = ''draft''::text) AND (created_by = auth.uid())) OR ((status_code <> ''draft''::text) AND ((created_by = auth.uid()) OR (responsible_profile_id = auth.uid()) OR is_activity_participant(id) OR can_manage_activity(scope_type, program_id, division_id, service_type_code))))', '<null>')
), expected_period_policy(policy_name, permissive, command_code, role_names, using_expression, check_expression) as (
  values ('Authenticated users can read academic periods', true, 'r', '{authenticated}', 'true', '<null>')
), table_acl_rows as (
  select relation_info.relname,
    case when expanded_acl.grantee = 0 then 'PUBLIC' else pg_catalog.pg_get_userbyid(expanded_acl.grantee) end grantee_name,
    expanded_acl.privilege_type,
    expanded_acl.is_grantable
  from pg_catalog.pg_class relation_info
  join pg_catalog.pg_namespace namespace_info on namespace_info.oid = relation_info.relnamespace
  cross join lateral pg_catalog.aclexplode(coalesce(relation_info.relacl, pg_catalog.acldefault('r', relation_info.relowner))) expanded_acl
  where namespace_info.nspname = 'public'
    and relation_info.relname in ('activities', 'academic_periods', 'academic_period_audit_events')
    and expanded_acl.grantee <> relation_info.relowner
), expected_activity_acl(grantee_name, privilege_type, is_grantable) as (
  values
    ('authenticated','DELETE',false), ('authenticated','INSERT',false), ('authenticated','SELECT',false), ('authenticated','UPDATE',false),
    ('service_role','DELETE',false), ('service_role','INSERT',false), ('service_role','MAINTAIN',false), ('service_role','REFERENCES',false),
    ('service_role','SELECT',false), ('service_role','TRIGGER',false), ('service_role','TRUNCATE',false), ('service_role','UPDATE',false)
), expected_period_acl_post0010(grantee_name, privilege_type, is_grantable) as (
  values
    ('authenticated','SELECT',false),
    ('service_role','DELETE',false), ('service_role','INSERT',false), ('service_role','MAINTAIN',false), ('service_role','REFERENCES',false),
    ('service_role','SELECT',false), ('service_role','TRIGGER',false), ('service_role','TRUNCATE',false), ('service_role','UPDATE',false)
), expected_period_acl_post0011(grantee_name, privilege_type, is_grantable) as (
  values ('authenticated','SELECT',false), ('service_role','SELECT',false)
), routine_acl_rows as (
  select 'routine_acl|' || selected.signature || '|grantee=' ||
    case when expanded_acl.grantee = 0 then 'PUBLIC' else pg_catalog.pg_get_userbyid(expanded_acl.grantee) end ||
    '|grantor=' || pg_catalog.pg_get_userbyid(expanded_acl.grantor) ||
    '|privilege=' || expanded_acl.privilege_type || '|grantable=' || expanded_acl.is_grantable::text as value,
    selected.signature,
    selected.proowner,
    expanded_acl.grantee,
    expanded_acl.grantor = selected.proowner as grantor_is_owner,
    case when expanded_acl.grantee = 0 then 'PUBLIC' else pg_catalog.pg_get_userbyid(expanded_acl.grantee) end as grantee_name,
    expanded_acl.privilege_type,
    expanded_acl.is_grantable
  from selected_functions selected
  cross join lateral pg_catalog.aclexplode(coalesce(
    (select procedure_info.proacl from pg_catalog.pg_proc procedure_info where procedure_info.oid = selected.oid),
    pg_catalog.acldefault('f', selected.proowner)
  )) expanded_acl
), expected_nonowner_acl(signature, grantor_is_owner, grantee_name, privilege_type, is_grantable) as (
  values
    ('public.get_academic_period_for_date(date)', true, 'authenticated', 'EXECUTE', false),
    ('public.get_academic_period_for_date(date)', true, 'service_role', 'EXECUTE', false),
    ('public.publish_activity(uuid)', true, 'authenticated', 'EXECUTE', false),
    ('public.publish_activity(uuid)', true, 'service_role', 'EXECUTE', false),
    ('public.list_admin_academic_periods(integer,integer)', true, 'authenticated', 'EXECUTE', false),
    ('public.create_admin_academic_period(text,date,date,boolean)', true, 'authenticated', 'EXECUTE', false),
    ('public.correct_admin_academic_period(uuid,text,date,date,text)', true, 'authenticated', 'EXECUTE', false),
    ('public.activate_admin_academic_period(uuid,text)', true, 'authenticated', 'EXECUTE', false),
    ('public.deactivate_admin_academic_period(uuid,text)', true, 'authenticated', 'EXECUTE', false)
), expected_nonowner_acl_post0010(signature, grantor_is_owner, grantee_name, privilege_type, is_grantable) as (
  values
    ('public.get_academic_period_for_date(date)', true, 'authenticated', 'EXECUTE', false),
    ('public.get_academic_period_for_date(date)', true, 'service_role', 'EXECUTE', false),
    ('public.publish_activity(uuid)', true, 'authenticated', 'EXECUTE', false),
    ('public.publish_activity(uuid)', true, 'service_role', 'EXECUTE', false)
), observed_nonowner_acl as (
  select signature, grantor_is_owner, grantee_name, privilege_type, is_grantable
  from routine_acl_rows
  where grantee <> proowner
), contract_rows as (
  select value from function_rows
  union all select value from trigger_rows
  union all select value from constraint_rows
  union all select value from index_rows
  union all select value from table_security_rows
  union all select 'policy|' || relname || '|' || polname || '|permissive=' || polpermissive::text || '|command=' || command_code || '|roles=' || role_names || '|using=' || using_expression || '|check=' || check_expression from policy_rows
  union all select 'table_acl|' || relname || '|grantee=' || grantee_name || '|privilege=' || privilege_type || '|grantable=' || is_grantable::text from table_acl_rows
  union all select value from routine_acl_rows
), ms20_candidates as (
$ms20CandidateSetSql
), selected_ms20_candidate as (
  select candidate.id
  from ms20_candidates candidate
  order by candidate.id
  limit 1
), baseline_raw as (
  select
    (select count(*) from public.academic_periods) as period_count,
    (select coalesce(md5(string_agg(jsonb_build_object(
      'id', period.id, 'code', period.code, 'name', period.name,
      'starts_on', period.starts_on, 'ends_on', period.ends_on,
      'is_active', period.is_active, 'sort_order', period.sort_order,
      'created_at', period.created_at, 'updated_at', period.updated_at
    )::text, E'\n' order by period.code collate "C", period.id)), md5('')) from public.academic_periods period) as period_hash,
    (select md5(string_agg(period.id::text || '|' || period.code, E'\n' order by period.code collate "C")) from public.academic_periods period) as identity_hash,
    (select count(*) from public.activities) as activity_count,
    (select count(*) from exact_admins) as exact_admin_count,
    (select count(*) from exact_admins admin join public.profiles profile on profile.id = admin.user_id where profile.email like '%@example.invalid') as synthetic_admin_count,
    (select coalesce(md5(string_agg(admin.user_id::text, E'\n' order by admin.user_id)), md5('')) from exact_admins admin) as authority_hash,
    (select count(*) from ms20_candidates) as ms20_candidate_count,
    (select coalesce(md5(string_agg(candidate.id::text, E'\n' order by candidate.id)), md5('')) from ms20_candidates candidate) as ms20_candidate_set_hash,
    (select count(*) from selected_ms20_candidate) as ms20_selected_candidate_count,
    not exists (
      select 1
      from ms20_candidates candidate
      join public.profiles profile on profile.id = candidate.id
      where profile.email not like '%@example.invalid'
    ) as ms20_candidates_all_synthetic,
    not exists (
      select 1
      from ms20_candidates candidate
      join exact_admins admin on admin.user_id = candidate.id
    ) as ms20_candidates_exclude_exact_active_admins,
    (select coalesce(md5(string_agg(jsonb_build_object(
      'id', assignment.id, 'user_id', assignment.user_id, 'role_code', assignment.role_code,
      'scope_type', assignment.scope_type, 'service_area', assignment.service_area,
      'division_id', assignment.division_id, 'program_id', assignment.program_id,
      'starts_at', assignment.starts_at, 'ends_at', assignment.ends_at,
      'is_active', assignment.is_active, 'assigned_by', assignment.assigned_by,
      'created_at', assignment.created_at, 'updated_at', assignment.updated_at
    )::text, E'\n' order by assignment.id)), md5('')) from public.role_assignments assignment) as assignment_hash,
    (select count(*) from pg_catalog.pg_locks lock where lock.locktype = 'advisory' and lock.classid = $($script:Sem01AdvisoryKeyOne) and lock.objid = $($script:Sem01AdvisoryKeyTwo) and lock.objsubid = $($script:Sem01AdvisoryObjSubId) and lock.granted) as granted_advisory_count,
    (select count(*) from pg_catalog.pg_locks lock where lock.locktype = 'advisory' and lock.classid = $($script:Sem01AdvisoryKeyOne) and lock.objid = $($script:Sem01AdvisoryKeyTwo) and lock.objsubid = $($script:Sem01AdvisoryObjSubId) and not lock.granted) as waiting_advisory_count,
    (select count(*) from pg_catalog.pg_locks lock where lock.locktype = 'advisory' and lock.classid = $($script:Sem01AdvisoryKeyOne) and lock.objid = $($script:Sem01AdvisoryKeyTwo) and lock.objsubid = $($script:Sem01AdvisoryObjSubId)) as total_advisory_count,
    (select count(*) from pg_catalog.pg_stat_activity activity where activity.pid <> pg_backend_pid() and activity.application_name like 'sitaa_sem01_%') as harness_session_count,
    (select count(*) from pg_catalog.pg_class relation join pg_catalog.pg_namespace namespace on namespace.oid = relation.relnamespace where namespace.nspname like 'sitaa_sem01_%') as temporary_object_count,
    (select md5(normalized_definition) from selected_functions where signature = 'public.get_academic_period_for_date(date)') as resolver_hash,
    (select coalesce(md5(string_agg(value, E'\n' order by value collate "C")), md5('')) from contract_rows) as boundary_contract_hash,
    (select count(*) from selected_functions) as function_inventory_count,
    (select coalesce(md5(string_agg(signature, E'\n' order by signature collate "C")), md5('')) from selected_functions) as function_inventory_hash,
    case when '$ExpectedState' = 'POST0011' then
      ((select count(*) from selected_functions) = 18 and
       not exists (select signature from expected_functions except select signature from selected_functions) and
       not exists (select signature from selected_functions except select signature from expected_functions))
    else
      ((select count(*) from selected_functions) = 3 and
       not exists (select signature from post0010_functions except select signature from selected_functions) and
       not exists (select signature from selected_functions except select signature from post0010_functions))
    end as function_inventory_valid,
    (select count(*) from trigger_rows) as expected_trigger_match_count,
    (select coalesce(md5(string_agg(value, E'\n' order by value collate "C")), md5('')) from trigger_rows) as trigger_inventory_hash,
    case when '$ExpectedState' = 'POST0011' then
      ((select count(*) from trigger_rows) = 10 and
       not exists (select relation_name, trigger_name, trigger_definition, enabled_state from expected_post0011_triggers
         except select relname, tgname, trigger_definition, enabled_state from trigger_rows) and
       not exists (select relname, tgname, trigger_definition, enabled_state from trigger_rows
         except select relation_name, trigger_name, trigger_definition, enabled_state from expected_post0011_triggers))
    else
      ((select count(*) from trigger_rows) = 3 and
       not exists (select relation_name, trigger_name, trigger_definition, enabled_state from expected_post0010_triggers
         except select relname, tgname, trigger_definition, enabled_state from trigger_rows) and
       not exists (select relname, tgname, trigger_definition, enabled_state from trigger_rows
         except select relation_name, trigger_name, trigger_definition, enabled_state from expected_post0010_triggers))
    end as trigger_inventory_valid,
    (select coalesce(md5(string_agg(value, E'\n' order by value collate "C")), md5('')) from constraint_rows) as constraint_inventory_hash,
    (select count(*) from constraint_rows where relname = 'academic_period_audit_events') as audit_constraint_count,
    ((select count(*) from constraint_rows where relname = 'activities') = 17 and
     not exists (select constraint_name, constraint_definition from expected_activities_constraints
       except select conname, constraint_definition from constraint_rows where relname = 'activities') and
     not exists (select conname, constraint_definition from constraint_rows where relname = 'activities'
       except select constraint_name, constraint_definition from expected_activities_constraints) and
     not exists (select 1 from constraint_rows where relname = 'activities' and (not convalidated or condeferrable or condeferred)))
      as activities_constraint_inventory_valid,
    case when '$ExpectedState' = 'POST0011' then
      ((select count(*) from constraint_rows where relname = 'academic_periods') = 4 and
       not exists (select constraint_name, constraint_definition from expected_period_constraints_post0011
         except select conname, constraint_definition from constraint_rows where relname = 'academic_periods') and
       not exists (select conname, constraint_definition from constraint_rows where relname = 'academic_periods'
         except select constraint_name, constraint_definition from expected_period_constraints_post0011) and
       not exists (select 1 from constraint_rows where relname = 'academic_periods' and (not convalidated or condeferrable or condeferred)))
    else
      ((select count(*) from constraint_rows where relname = 'academic_periods') = 2 and
       not exists (select constraint_name, constraint_definition from expected_period_constraints_post0010
         except select conname, constraint_definition from constraint_rows where relname = 'academic_periods') and
       not exists (select conname, constraint_definition from constraint_rows where relname = 'academic_periods'
         except select constraint_name, constraint_definition from expected_period_constraints_post0010) and
       not exists (select 1 from constraint_rows where relname = 'academic_periods' and (not convalidated or condeferrable or condeferred)))
    end as period_constraint_inventory_valid,
    case when '$ExpectedState' = 'POST0011' then
      ((select count(*) from constraint_rows where relname = 'academic_period_audit_events') = 7 and
       not exists (select constraint_name, constraint_definition from expected_audit_constraints
         except select conname, constraint_definition from constraint_rows where relname = 'academic_period_audit_events') and
       not exists (select conname, constraint_definition from constraint_rows where relname = 'academic_period_audit_events'
         except select constraint_name, constraint_definition from expected_audit_constraints) and
       not exists (select 1 from constraint_rows where relname = 'academic_period_audit_events' and (not convalidated or condeferrable or condeferred)))
    else (select count(*) from constraint_rows where relname = 'academic_period_audit_events') = 0
    end as audit_constraint_inventory_valid,
    (select coalesce(md5(string_agg(value, E'\n' order by value collate "C")), md5('')) from index_rows) as index_inventory_hash,
    (select coalesce(md5(string_agg(value, E'\n' order by value collate "C")), md5('')) from table_security_rows) as table_security_hash,
    case when '$ExpectedState' = 'POST0011' then
      ((select count(*) from index_rows where relname = 'academic_periods') = 3 and
       not exists (select index_name, index_definition from expected_period_indexes_post0011 except select index_name, index_definition from index_rows where relname = 'academic_periods') and
       not exists (select index_name, index_definition from index_rows where relname = 'academic_periods' except select index_name, index_definition from expected_period_indexes_post0011) and
       (select count(*) from index_rows where relname = 'academic_period_audit_events') = 3 and
       not exists (select index_name, index_definition from expected_audit_indexes except select index_name, index_definition from index_rows where relname = 'academic_period_audit_events') and
       not exists (select index_name, index_definition from index_rows where relname = 'academic_period_audit_events' except select index_name, index_definition from expected_audit_indexes))
    else ((select count(*) from index_rows where relname = 'academic_periods') = 2 and
       not exists (select index_name, index_definition from expected_period_indexes_post0010 except select index_name, index_definition from index_rows where relname = 'academic_periods') and
       not exists (select index_name, index_definition from index_rows where relname = 'academic_periods' except select index_name, index_definition from expected_period_indexes_post0010) and
       (select count(*) from index_rows where relname = 'academic_period_audit_events') = 0)
    end as complete_index_inventory_valid,
    case when '$ExpectedState' = 'POST0011' then
      ((select count(*) from table_security_rows) = 3 and
       not exists (select 1 from table_security_rows where not relrowsecurity or relforcerowsecurity))
    else
      ((select count(*) from table_security_rows) = 2 and
       not exists (select 1 from table_security_rows where relname in ('activities','academic_periods') and (not relrowsecurity or relforcerowsecurity)))
    end as rls_contract_valid,
    (not exists (select policy_name, permissive, command_code, role_names, using_expression, check_expression from expected_activity_policies
       except select polname, polpermissive, command_code, role_names, using_expression, check_expression from policy_rows where relname = 'activities') and
     not exists (select polname, polpermissive, command_code, role_names, using_expression, check_expression from policy_rows where relname = 'activities'
       except select policy_name, permissive, command_code, role_names, using_expression, check_expression from expected_activity_policies) and
     not exists (select policy_name, permissive, command_code, role_names, using_expression, check_expression from expected_period_policy
       except select polname, polpermissive, command_code, role_names, using_expression, check_expression from policy_rows where relname = 'academic_periods') and
     not exists (select polname, polpermissive, command_code, role_names, using_expression, check_expression from policy_rows where relname = 'academic_periods'
       except select policy_name, permissive, command_code, role_names, using_expression, check_expression from expected_period_policy) and
     not exists (select 1 from policy_rows where relname = 'academic_period_audit_events')) as policy_contract_valid,
    case when '$ExpectedState' = 'POST0011' then
      (not exists (select grantee_name, privilege_type, is_grantable from expected_activity_acl except select grantee_name, privilege_type, is_grantable from table_acl_rows where relname = 'activities') and
       not exists (select grantee_name, privilege_type, is_grantable from table_acl_rows where relname = 'activities' except select grantee_name, privilege_type, is_grantable from expected_activity_acl) and
       not exists (select grantee_name, privilege_type, is_grantable from expected_period_acl_post0011 except select grantee_name, privilege_type, is_grantable from table_acl_rows where relname = 'academic_periods') and
       not exists (select grantee_name, privilege_type, is_grantable from table_acl_rows where relname = 'academic_periods' except select grantee_name, privilege_type, is_grantable from expected_period_acl_post0011) and
       not exists (select 1 from table_acl_rows where relname = 'academic_period_audit_events'))
    else
      (not exists (select grantee_name, privilege_type, is_grantable from expected_activity_acl except select grantee_name, privilege_type, is_grantable from table_acl_rows where relname = 'activities') and
       not exists (select grantee_name, privilege_type, is_grantable from table_acl_rows where relname = 'activities' except select grantee_name, privilege_type, is_grantable from expected_activity_acl) and
       not exists (select grantee_name, privilege_type, is_grantable from expected_period_acl_post0010 except select grantee_name, privilege_type, is_grantable from table_acl_rows where relname = 'academic_periods') and
       not exists (select grantee_name, privilege_type, is_grantable from table_acl_rows where relname = 'academic_periods' except select grantee_name, privilege_type, is_grantable from expected_period_acl_post0010) and
       not exists (select 1 from table_acl_rows where relname = 'academic_period_audit_events'))
    end as table_acl_contract_valid,
    (select coalesce(md5(string_agg(value, E'\n' order by value collate "C")), md5('')) from routine_acl_rows) as routine_acl_hash,
    case when '$ExpectedState' = 'POST0011' then
      (not exists (select signature, grantor_is_owner, grantee_name, privilege_type, is_grantable from expected_nonowner_acl except select signature, grantor_is_owner, grantee_name, privilege_type, is_grantable from observed_nonowner_acl) and
       not exists (select signature, grantor_is_owner, grantee_name, privilege_type, is_grantable from observed_nonowner_acl except select signature, grantor_is_owner, grantee_name, privilege_type, is_grantable from expected_nonowner_acl) and
       not exists (select 1 from routine_acl_rows where grantee_name in ('PUBLIC', 'anon')))
    else
      (not exists (select signature, grantor_is_owner, grantee_name, privilege_type, is_grantable from expected_nonowner_acl_post0010 except select signature, grantor_is_owner, grantee_name, privilege_type, is_grantable from observed_nonowner_acl) and
       not exists (select signature, grantor_is_owner, grantee_name, privilege_type, is_grantable from observed_nonowner_acl except select signature, grantor_is_owner, grantee_name, privilege_type, is_grantable from expected_nonowner_acl_post0010) and
       not exists (select 1 from routine_acl_rows where grantee_name in ('PUBLIC', 'anon')))
    end as routine_acl_valid,
    (select count(*) from pg_catalog.pg_proc procedure_info
      join pg_catalog.pg_namespace namespace_info on namespace_info.oid = procedure_info.pronamespace
      where namespace_info.nspname = 'public' and procedure_info.proname like '%\_0011' escape '\'
        and not exists (select 1 from selected_functions selected where selected.oid = procedure_info.oid)) as nonexistent_helper_count,
    case when to_regprocedure('public.acquire_sem01_calendar_lock_0011()') is null then 0 else 1 end as calendar_lock_helper_count,
    case when to_regclass('public.academic_period_audit_events') is null then 0 else 1 end as audit_table,
    case when to_regprocedure('public.list_admin_academic_periods(integer,integer)') is null then 0 else 1 end as admin_list,
    (select count(*) from public.academic_periods where code in ('2098-1', '2098-2', '2099-1', '2099-2')) as fixture_period_count,
    $auditCountSql as audit_event_count
), baseline as (
  select baseline_raw.*,
    trigger_inventory_valid as complete_trigger_inventory_valid,
    audit_constraint_inventory_valid as complete_audit_constraint_inventory_valid,
    (table_acl_contract_valid and rls_contract_valid and policy_contract_valid) as table_security_valid
  from baseline_raw
)
select 'BASELINE|' || '$ExpectedState' || '|' || period_count || '|' || period_hash || '|' || identity_hash || '|' || activity_count || '|' || exact_admin_count || '|' || synthetic_admin_count || '|' || authority_hash || '|' || assignment_hash || '|' || granted_advisory_count || '|' || waiting_advisory_count || '|' || total_advisory_count || '|' || harness_session_count || '|' || temporary_object_count || '|' || resolver_hash || '|' || boundary_contract_hash || '|' || function_inventory_count || '|' || function_inventory_hash || '|' || function_inventory_valid::int || '|' || expected_trigger_match_count || '|' || trigger_inventory_hash || '|' || trigger_inventory_valid::int || '|' || constraint_inventory_hash || '|' || audit_constraint_count || '|' || audit_constraint_inventory_valid::int || '|' || index_inventory_hash || '|' || table_security_hash || '|' || table_security_valid::int || '|' || routine_acl_hash || '|' || routine_acl_valid::int || '|' || nonexistent_helper_count || '|' || calendar_lock_helper_count || '|' || audit_table || '|' || admin_list || '|' || fixture_period_count || '|' || audit_event_count || '|' || complete_trigger_inventory_valid::int || '|' || activities_constraint_inventory_valid::int || '|' || period_constraint_inventory_valid::int || '|' || complete_audit_constraint_inventory_valid::int || '|' || complete_index_inventory_valid::int || '|' || table_acl_contract_valid::int || '|' || rls_contract_valid::int || '|' || policy_contract_valid::int || '|' || ms20_candidate_count || '|' || ms20_candidate_set_hash || '|' || ms20_selected_candidate_count || '|' || ms20_candidates_all_synthetic::int || '|' || ms20_candidates_exclude_exact_active_admins::int
from baseline;
rollback;
"@
}

function Get-DatabasePhase {
  param(
    [Parameter(Mandatory = $true)][object]$Connection,
    [Parameter(Mandatory = $true)][string]$PsqlPath,
    [Parameter(Mandatory = $true)][string]$RunDirectory
  )
  $diagnostic = Invoke-ReadOnlyDatabaseDiagnostic -Connection $Connection -PsqlPath $PsqlPath -RunDirectory $RunDirectory
  Assert-Condition -Condition ($diagnostic.DatabaseState -in @("POST0010", "POST0011")) -Code "database_phase_unknown"
  return $diagnostic.DatabaseState
}

function Invoke-ReadOnlyFingerprint {
  param(
    [Parameter(Mandatory = $true)][object]$Connection,
    [Parameter(Mandatory = $true)][string]$PsqlPath,
    [Parameter(Mandatory = $true)][string]$RunDirectory,
    [Parameter(Mandatory = $true)][ValidateSet("POST0010", "POST0011")][string]$ExpectedState
  )
  $result = Invoke-PsqlSql -Connection $Connection -PsqlPath $PsqlPath -Sql (Get-BaselineProbeSql -ExpectedState $ExpectedState) -ApplicationName "sitaa_sem01_baseline_probe" -RunDirectory $RunDirectory
  Assert-PsqlApproved -Result $result -FailureCode "database_baseline_probe_failed"
  $parts = Get-MarkerParts -Result $result -Marker "BASELINE"
  Assert-Condition -Condition ($parts.Count -eq 50) -Code "database_baseline_shape_rejected"
  Assert-Condition -Condition ($parts[1] -eq $ExpectedState) -Code "database_baseline_state_rejected"
  return [pscustomobject]@{
    State = $parts[1]
    Periods = [int]$parts[2]
    PeriodHash = $parts[3]
    PeriodIdentityHash = $parts[4]
    Activities = [int]$parts[5]
    ExactAuthorities = [int]$parts[6]
    SyntheticAuthorities = [int]$parts[7]
    AuthorityHash = $parts[8]
    AssignmentHash = $parts[9]
    GrantedSem01AdvisoryLocks = [int]$parts[10]
    WaitingSem01AdvisoryLocks = [int]$parts[11]
    TotalSem01AdvisoryLocks = [int]$parts[12]
    OpenWorkers = [int]$parts[13]
    TransientWorkerSqlFiles = Get-TransientWorkerSqlFileCount -RunDirectory $RunDirectory
    TemporaryObjects = [int]$parts[14]
    ResolverHash = $parts[15]
    BoundaryContractHash = $parts[16]
    FunctionInventoryCount = [int]$parts[17]
    FunctionInventoryHash = $parts[18]
    FunctionInventoryValid = ([int]$parts[19] -eq 1)
    ExpectedTriggerMatchCount = [int]$parts[20]
    TriggerInventoryHash = $parts[21]
    TriggerInventoryValid = ([int]$parts[22] -eq 1)
    ConstraintInventoryHash = $parts[23]
    AuditConstraintCount = [int]$parts[24]
    AuditConstraintInventoryValid = ([int]$parts[25] -eq 1)
    IndexInventoryHash = $parts[26]
    TableSecurityHash = $parts[27]
    TableSecurityValid = ([int]$parts[28] -eq 1)
    RoutineAclHash = $parts[29]
    RoutineAclValid = ([int]$parts[30] -eq 1)
    NonexistentHelperCount = [int]$parts[31]
    CalendarLockHelperCount = [int]$parts[32]
    AuditTable = [int]$parts[33]
    AdminList = [int]$parts[34]
    FixturePeriods = [int]$parts[35]
    AuditEvents = [int]$parts[36]
    CompleteTriggerInventoryValid = ([int]$parts[37] -eq 1)
    ActivitiesConstraintInventoryValid = ([int]$parts[38] -eq 1)
    PeriodConstraintInventoryValid = ([int]$parts[39] -eq 1)
    CompleteAuditConstraintInventoryValid = ([int]$parts[40] -eq 1)
    CompleteIndexInventoryValid = ([int]$parts[41] -eq 1)
    TableAclContractValid = ([int]$parts[42] -eq 1)
    RlsContractValid = ([int]$parts[43] -eq 1)
    PolicyContractValid = ([int]$parts[44] -eq 1)
    Ms20CandidateCount = [int]$parts[45]
    Ms20CandidateSetHash = [string]$parts[46]
    Ms20SelectedCandidateCount = [int]$parts[47]
    Ms20CandidatesAllSynthetic = ([int]$parts[48] -eq 1)
    Ms20CandidatesExcludeExactActiveAdmins = ([int]$parts[49] -eq 1)
  }
}

function Invoke-ReadOnlyBaseline {
  param(
    [Parameter(Mandatory = $true)][object]$Connection,
    [Parameter(Mandatory = $true)][string]$PsqlPath,
    [Parameter(Mandatory = $true)][string]$RunDirectory,
    [Parameter(Mandatory = $true)][ValidateSet("POST0010", "POST0011")][string]$ExpectedState,
    [int]$ExpectedActivityCount = 0,
    [int]$ExpectedAuditEventCount = 0
  )
  $fingerprint = Invoke-ReadOnlyFingerprint -Connection $Connection -PsqlPath $PsqlPath -RunDirectory $RunDirectory -ExpectedState $ExpectedState
  Assert-Condition -Condition ($fingerprint.Periods -eq 5) -Code "canonical_period_count_rejected"
  Assert-Condition -Condition ($fingerprint.PeriodIdentityHash -eq "8af9fc114f31320519e894770823cc1d") -Code "canonical_period_identity_rejected"
  Assert-Condition -Condition ($fingerprint.Activities -eq $ExpectedActivityCount) -Code "unexpected_activity_rows"
  Assert-Condition -Condition ($fingerprint.ExactAuthorities -eq 2 -and $fingerprint.SyntheticAuthorities -eq 2) -Code "synthetic_authority_baseline_rejected"
  Assert-Condition -Condition ($fingerprint.Ms20CandidateCount -ge 1) -Code "ms20_candidate_baseline_missing"
  Assert-Condition -Condition (Test-LowercaseMd5 -Value $fingerprint.Ms20CandidateSetHash) -Code "ms20_candidate_set_hash_rejected"
  Assert-Condition -Condition ($fingerprint.Ms20SelectedCandidateCount -eq 1 -and $fingerprint.Ms20CandidatesAllSynthetic -and
    $fingerprint.Ms20CandidatesExcludeExactActiveAdmins) -Code "ms20_candidate_baseline_contract_rejected"
  Assert-Condition -Condition ($fingerprint.GrantedSem01AdvisoryLocks -eq 0 -and $fingerprint.WaitingSem01AdvisoryLocks -eq 0 -and
    $fingerprint.TotalSem01AdvisoryLocks -eq 0 -and $fingerprint.TransientWorkerSqlFiles -eq 0 -and
    $fingerprint.OpenWorkers -eq 0 -and $fingerprint.TemporaryObjects -eq 0) -Code "unexplained_runtime_state_rejected"
  Assert-Condition -Condition ($fingerprint.FixturePeriods -eq 0 -and $fingerprint.AuditEvents -eq $ExpectedAuditEventCount) -Code "fixture_or_audit_residue_rejected"
  Assert-Condition -Condition ($fingerprint.CompleteTriggerInventoryValid -and $fingerprint.ActivitiesConstraintInventoryValid -and
    $fingerprint.PeriodConstraintInventoryValid -and $fingerprint.CompleteAuditConstraintInventoryValid -and $fingerprint.CompleteIndexInventoryValid -and
    $fingerprint.TableAclContractValid -and $fingerprint.RlsContractValid -and $fingerprint.PolicyContractValid) -Code "exact_boundary_inventory_rejected"
  if ($ExpectedState -eq "POST0010") {
    Assert-Condition -Condition ($fingerprint.ResolverHash -eq "dd112ebab92161480ffedfe0d094b297") -Code "post0010_resolver_rejected"
    Assert-Condition -Condition ($fingerprint.AuditTable -eq 0 -and $fingerprint.AdminList -eq 0) -Code "pre0011_object_absence_rejected"
    Assert-Condition -Condition ($fingerprint.FunctionInventoryCount -eq 3 -and $fingerprint.FunctionInventoryValid) -Code "post0010_function_inventory_rejected"
    Assert-Condition -Condition ($fingerprint.ExpectedTriggerMatchCount -eq 3 -and $fingerprint.TriggerInventoryValid) -Code "post0010_trigger_inventory_rejected"
    Assert-Condition -Condition ($fingerprint.AuditConstraintCount -eq 0 -and $fingerprint.AuditConstraintInventoryValid) -Code "post0010_audit_constraint_inventory_rejected"
    Assert-Condition -Condition ($fingerprint.TableSecurityValid -and $fingerprint.NonexistentHelperCount -eq 0 -and $fingerprint.CalendarLockHelperCount -eq 0) -Code "post0010_boundary_inventory_rejected"
  }
  else {
    Assert-Condition -Condition ($fingerprint.ResolverHash -ne "dd112ebab92161480ffedfe0d094b297") -Code "post0011_resolver_rejected"
    Assert-Condition -Condition ($fingerprint.AuditTable -eq 1 -and $fingerprint.AdminList -eq 1) -Code "post0011_object_presence_rejected"
    Assert-Condition -Condition ($fingerprint.FunctionInventoryCount -eq 18 -and $fingerprint.FunctionInventoryValid) -Code "post0011_function_inventory_rejected"
    Assert-Condition -Condition ($fingerprint.ExpectedTriggerMatchCount -eq 10 -and $fingerprint.TriggerInventoryValid) -Code "post0011_trigger_inventory_rejected"
    Assert-Condition -Condition ($fingerprint.AuditConstraintCount -eq 7 -and $fingerprint.AuditConstraintInventoryValid) -Code "post0011_audit_constraint_inventory_rejected"
    Assert-Condition -Condition ($fingerprint.TableSecurityValid -and $fingerprint.RoutineAclValid) -Code "post0011_security_contract_rejected"
    Assert-Condition -Condition ($fingerprint.NonexistentHelperCount -eq 0 -and $fingerprint.CalendarLockHelperCount -eq 1) -Code "post0011_helper_inventory_rejected"
  }
  return $fingerprint
}

function Invoke-ReadOnlyDatabasePostcheck {
  param(
    [Parameter(Mandatory = $true)][object]$Connection,
    [Parameter(Mandatory = $true)][string]$PsqlPath,
    [Parameter(Mandatory = $true)][string]$RunDirectory
  )
  $diagnostic = Invoke-ReadOnlyDatabaseDiagnostic -Connection $Connection -PsqlPath $PsqlPath -RunDirectory $RunDirectory
  if ($diagnostic.DatabaseState -notin @("POST0010", "POST0011")) {
    return $diagnostic
  }
  $fingerprint = Invoke-ReadOnlyFingerprint -Connection $Connection -PsqlPath $PsqlPath -RunDirectory $RunDirectory -ExpectedState $diagnostic.DatabaseState
  $fingerprint | Add-Member -NotePropertyName DatabaseState -NotePropertyValue $diagnostic.DatabaseState
  $fingerprint | Add-Member -NotePropertyName FingerprintAvailable -NotePropertyValue $true
  $fingerprint | Add-Member -NotePropertyName PartialStateReason -NotePropertyValue $null
  foreach ($field in @("AuditTablePresent", "AdminListPresent", "CalendarLockHelperPresent", "PeriodRpcPresence", "TriggerPresence", "ConstraintPresence")) {
    $fingerprint | Add-Member -NotePropertyName $field -NotePropertyValue $diagnostic.$field
  }
  return $fingerprint
}

function Get-DiagnosticInventoryDisplayValue {
  param(
    [Parameter(Mandatory = $true)][object]$Diagnostic,
    [Parameter(Mandatory = $true)][string]$PropertyName
  )
  $value = $Diagnostic.$PropertyName
  if ($Diagnostic.FingerprintAvailable -ne $true -or $null -eq $value) { return "NOT_APPLICABLE" }
  return [string]$value
}

function Get-PostcheckDiagnosticLines {
  param(
    [Parameter(Mandatory = $true)][object]$Diagnostic,
    [Parameter(Mandatory = $true)][object]$Manifest,
    [Parameter(Mandatory = $true)][object]$Comparisons,
    [Parameter(Mandatory = $true)][string]$StableCode,
    [Parameter(Mandatory = $true)][bool]$Clean
  )
  $comparison = {
    param([bool]$Applicable, [bool]$Matches)
    if (-not $Applicable) { return "NOT_FROZEN" }
    if ($Matches) { return "MATCH" }
    return "DRIFT"
  }
  return @(
    "HARNESS_VERSION|$($script:HarnessVersion)",
    "TARGET_CLASS|DISPOSABLE_LAB",
    "RUN_STATUS|$($Manifest.RunStatus)",
    "COMPLETED_PHASE|$($Manifest.CompletedPhase)",
    "ACTIVE_PHASE|$(if ($null -eq $Manifest.ActivePhase) { '<none>' } else { $Manifest.ActivePhase })",
    "ACTIVE_SCENARIO|$(if ($null -eq $Manifest.ActiveScenario) { '<none>' } else { $Manifest.ActiveScenario })",
    "EXPECTED_DATABASE_STATE|$($Manifest.ExpectedDatabaseState)",
    "OBSERVED_DATABASE_STATE|$($Diagnostic.DatabaseState)",
    "PARTIAL_STATE_REASON|$(if ($null -eq $Diagnostic.PartialStateReason) { '<none>' } else { $Diagnostic.PartialStateReason })",
    "FINGERPRINT_AVAILABLE|$($Diagnostic.FingerprintAvailable -eq $true)",
    "OBJECT_AUDIT_TABLE|$([int]$Diagnostic.AuditTablePresent)",
    "OBJECT_ADMIN_LIST|$([int]$Diagnostic.AdminListPresent)",
    "OBJECT_CALENDAR_LOCK_HELPER|$([int]$Diagnostic.CalendarLockHelperPresent)",
    "OBJECT_PERIOD_RPCS|$(@($Diagnostic.PeriodRpcPresence) -join ',')",
    "OBJECT_TRIGGERS|$(@($Diagnostic.TriggerPresence) -join ',')",
    "OBJECT_CONSTRAINTS|$(@($Diagnostic.ConstraintPresence) -join ',')",
    "DATABASE_STATE_COMPARISON|$(& $comparison $true $Comparisons.StateMatches)",
    "CANONICAL_PERIOD_ROWS|$($Diagnostic.Periods)",
    "CANONICAL_PERIOD_FINGERPRINT|$(& $comparison $Comparisons.BaselineAvailable $Comparisons.PeriodMatches)",
    "EXACT_AUTHORITY_FINGERPRINT|$(& $comparison $Comparisons.BaselineAvailable $Comparisons.AuthorityMatches)",
    "EXACT_ASSIGNMENT_FINGERPRINT|$(& $comparison $Comparisons.BaselineAvailable $Comparisons.AssignmentMatches)",
    "MS20_CANDIDATE_SET_FINGERPRINT|$(& $comparison $Comparisons.BaselineAvailable $Comparisons.Ms20CandidateSetMatches)",
    "RESOLVER_FINGERPRINT|$(& $comparison $Comparisons.ResolverApplicable $Comparisons.ResolverMatches)",
    "POST0011_BOUNDARY_FINGERPRINT|$(& $comparison $Comparisons.BoundaryApplicable $Comparisons.BoundaryMatches)",
    "EXPECTED_FUNCTION_INVENTORY|$(Get-DiagnosticInventoryDisplayValue -Diagnostic $Diagnostic -PropertyName 'FunctionInventoryCount')",
    "EXPECTED_TRIGGER_MATCHES|$(Get-DiagnosticInventoryDisplayValue -Diagnostic $Diagnostic -PropertyName 'ExpectedTriggerMatchCount')",
    "AUDIT_CONSTRAINTS|$(Get-DiagnosticInventoryDisplayValue -Diagnostic $Diagnostic -PropertyName 'AuditConstraintCount')",
    "FIXTURE_PERIODS|$($Diagnostic.FixturePeriods)",
    "FIXTURE_ACTIVITIES|$($Diagnostic.Activities)",
    "PERIOD_AUDIT_EVENTS|$($Diagnostic.AuditEvents)",
    "OPEN_WORKERS_REMOTE|$($Diagnostic.OpenWorkers)",
    "ACTIVE_WORKER_PIDS_MANIFEST|$(@($Manifest.ActiveWorkerPids).Count)",
    "ACTIVE_WORKER_PIDS_LOCAL_FILE|$($Comparisons.PidFileCount)",
    "GRANTED_SEM01_ADVISORY_LOCKS|$($Diagnostic.GrantedSem01AdvisoryLocks)",
    "WAITING_SEM01_ADVISORY_LOCKS|$($Diagnostic.WaitingSem01AdvisoryLocks)",
    "TOTAL_SEM01_ADVISORY_LOCKS|$($Diagnostic.TotalSem01AdvisoryLocks)",
    "TRANSIENT_WORKER_SQL_FILES|$($Diagnostic.TransientWorkerSqlFiles)",
    "TEMPORARY_DATABASE_OBJECTS|$($Diagnostic.TemporaryObjects)",
    "EXPECTED_ACTIVITY_FIXTURE|$(if ($null -eq $Manifest.ExpectedActivityFixture) { 'ABSENT' } elseif ($Comparisons.ActivityFixtureMatches) { 'MATCH' } else { 'DRIFT' })",
    "MANIFEST_RUN_ID|$(if ($Comparisons.RunIdMatches) { 'MATCH' } else { 'DRIFT' })",
    "MANIFEST_SOURCE_HEAD|$(if ($Comparisons.SourceHeadMatches) { 'MATCH' } else { 'DRIFT' })",
    "MANIFEST_MIGRATION_SHA256|$(if ($Comparisons.MigrationHashMatches) { 'MATCH' } else { 'DRIFT' })",
    "MANIFEST_ROLLBACK_SHA256|$(if ($Comparisons.RollbackHashMatches) { 'MATCH' } else { 'DRIFT' })",
    "MANIFEST_HARNESS_SHA256|$(if ($Comparisons.HarnessHashMatches) { 'MATCH' } else { 'DRIFT' })",
    "MANIFEST_HARNESS_VERSION|$(if ($Comparisons.HarnessVersionMatches) { 'MATCH' } else { 'DRIFT' })",
    "PROTECTED_SOURCE_HASHES|$(if ($Comparisons.ProtectedSourcesMatch) { 'MATCH' } else { 'DRIFT' })",
    "APPROVED_EVIDENCE_STATE|$(if ($Comparisons.EvidenceContractMatches) { 'MATCH' } else { 'DRIFT' })",
    "APPROVED_POSTCHECK_PUBLISHING|$([int][bool]$Comparisons.ApprovedPostcheckPublishing)",
    "APPROVED_EVIDENCE_PUBLISHING|$([int][bool]$Comparisons.ApprovedEvidencePublishing)",
    "FAILURE_POSTCHECK_PUBLISHING|$([int][bool]$Comparisons.FailurePostcheckPublishing)",
    "REJECTED_EVIDENCE_PUBLISHING|$([int][bool]$Comparisons.RejectedEvidencePublishing)",
    "TERMINAL_PUBLISHING_ARTIFACTS|$([int]$Comparisons.TotalPublishingArtifacts)",
    $(if ($Clean) { "POSTCHECK_ONLY|CLEAN" } else { "POSTCHECK_ONLY|DRIFT_OR_RESIDUE|$StableCode" })
  )
}

function Get-ActivityFixtureSnapshot {
  param(
    [Parameter(Mandatory = $true)][object]$Connection,
    [Parameter(Mandatory = $true)][string]$PsqlPath,
    [Parameter(Mandatory = $true)][string]$RunDirectory,
    [Parameter(Mandatory = $true)][string]$ActivityId
  )
  Assert-Condition -Condition ($ActivityId -cmatch '^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$') -Code "activity_fixture_id_rejected"
  $sql = @"
begin;
set transaction isolation level read committed;
set transaction read only;
select 'ACTIVITY_FIXTURE|' ||
  (select count(*) from public.activities)::text || '|' ||
  (select count(*) from public.activities where id = '$ActivityId'::uuid)::text || '|' ||
  coalesce((select md5(to_jsonb(activity_row)::text) from public.activities activity_row where activity_row.id = '$ActivityId'::uuid), '<missing>');
rollback;
"@
  $result = Invoke-PsqlSql -Connection $Connection -PsqlPath $PsqlPath -Sql $sql -ApplicationName "sitaa_sem01_activity_fixture_probe" -RunDirectory $RunDirectory
  Assert-PsqlApproved -Result $result -FailureCode "activity_fixture_probe_failed"
  $parts = Get-MarkerParts -Result $result -Marker "ACTIVITY_FIXTURE"
  Assert-Condition -Condition ($parts.Count -eq 4) -Code "activity_fixture_probe_shape_rejected"
  return [pscustomobject]@{
    Activities = [int]$parts[1]
    MatchingRows = [int]$parts[2]
    Id = $ActivityId
    RowFingerprint = [string]$parts[3]
  }
}

function Get-SyntheticAuthorityIds {
  param(
    [Parameter(Mandatory = $true)][object]$Connection,
    [Parameter(Mandatory = $true)][string]$PsqlPath,
    [Parameter(Mandatory = $true)][string]$RunDirectory
  )
  $sql = @'
begin;
set transaction read only;
select 'AUTHORITY|' || assignment.user_id::text
from public.role_assignments assignment
join public.profiles profile on profile.id = assignment.user_id
where assignment.role_code = 'technical_admin'
  and assignment.scope_type = 'system'
  and assignment.service_area = 'technical'
  and assignment.program_id is null
  and assignment.division_id is null
  and assignment.is_active
  and (assignment.starts_at is null or assignment.starts_at <= (now() at time zone 'America/Mexico_City')::date)
  and (assignment.ends_at is null or assignment.ends_at >= (now() at time zone 'America/Mexico_City')::date)
  and profile.account_status = 'active'
  and profile.is_active
  and profile.email like '%@example.invalid'
order by assignment.user_id;
rollback;
'@
  $result = Invoke-PsqlSql -Connection $Connection -PsqlPath $PsqlPath -Sql $sql -ApplicationName "sitaa_sem01_authority_probe" -RunDirectory $RunDirectory -KeepRawLogs
  Assert-PsqlApproved -Result $result -FailureCode "synthetic_authority_probe_failed"
  $ids = @($result.Stdout -split "\r?\n" | Where-Object { $_.StartsWith("AUTHORITY|") } | ForEach-Object { $_.Split('|')[1] })
  Assert-Condition -Condition ($ids.Count -eq 2) -Code "synthetic_authority_count_rejected"
  foreach ($id in $ids) {
    Assert-Condition -Condition ($id -match '^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$') -Code "synthetic_authority_id_rejected"
  }
  return $ids
}

function New-ScenarioResult {
  param(
    [Parameter(Mandatory = $true)][string]$ScenarioId,
    [Parameter(Mandatory = $true)][hashtable]$Assertions,
    [Parameter(Mandatory = $true)][string]$Outcome
  )
  $scenario = $script:RequiredScenarios | Where-Object { $_.Id -eq $ScenarioId } | Select-Object -First 1
  Assert-Condition -Condition ($null -ne $scenario) -Code "scenario_result_unknown"
  Assert-Condition -Condition ($Assertions.Count -gt 0) -Code "scenario_assertions_missing"
  foreach ($assertion in $Assertions.GetEnumerator()) {
    Assert-Condition -Condition ($assertion.Value -eq $true) -Code ("scenario_assertion_rejected_" + $assertion.Key)
  }
  return [pscustomobject]@{ Id = $ScenarioId; Assertions = $Assertions; Outcome = $Outcome; CompletedAtUtc = [DateTime]::UtcNow.ToString("o") }
}

function Approve-ScenarioResult {
  param(
    [Parameter(Mandatory = $true)][System.Collections.ArrayList]$ApprovedResults,
    [Parameter(Mandatory = $true)][object]$Manifest,
    [Parameter(Mandatory = $true)][object]$Paths,
    [Parameter(Mandatory = $true)][object]$Result
  )
  $scenario = $script:RequiredScenarios | Where-Object { $_.Id -eq $Result.Id } | Select-Object -First 1
  Assert-Condition -Condition ($null -ne $scenario) -Code "scenario_approval_unknown"
  Assert-Condition -Condition ([string]$Manifest.RunStatus -ceq "running") -Code "scenario_approval_run_not_active"
  Assert-Condition -Condition ([string]$Manifest.ActivePhase -ceq [string]$scenario.Phase) -Code "scenario_approval_phase_rejected"
  Assert-Condition -Condition ([string]$Manifest.ActiveScenario -ceq [string]$Result.Id) -Code "scenario_approval_not_next"
  Assert-Condition -Condition (@($ApprovedResults | Where-Object { $_.Id -eq $Result.Id }).Count -eq 0) -Code "scenario_approval_duplicate"
  Assert-Condition -Condition ($Result.Assertions.Count -gt 0) -Code "scenario_approval_without_assertions"
  foreach ($assertion in $Result.Assertions.GetEnumerator()) {
    Assert-Condition -Condition ($assertion.Value -eq $true) -Code "scenario_approval_failed_assertion"
  }
  [void]$ApprovedResults.Add($Result)
  $Manifest.ApprovedScenarios = @($ApprovedResults | ForEach-Object { $_.Id })
  $Manifest.ApprovedScenarioResults = @($ApprovedResults | ForEach-Object {
    [ordered]@{ Id = $_.Id; Outcome = $_.Outcome; Assertions = $_.Assertions; CompletedAtUtc = $_.CompletedAtUtc }
  })
  $phaseIds = @(Get-ScenarioIdsForPhase -Phase ([string]$Manifest.ActivePhase))
  $Manifest.ActiveScenario = $phaseIds | Where-Object { $_ -notin @($ApprovedResults | ForEach-Object { $_.Id }) } | Select-Object -First 1
  Write-Manifest -Paths $Paths -Manifest $Manifest
  Clear-CurrentScenario
}

function Set-ManifestPhase {
  param(
    [Parameter(Mandatory = $true)][object]$Manifest,
    [Parameter(Mandatory = $true)][object]$Paths,
    [Parameter(Mandatory = $true)][string]$Phase,
    [Parameter(Mandatory = $true)][string]$ExpectedDatabaseState,
    [Parameter(Mandatory = $true)][System.Collections.ArrayList]$ApprovedResults,
    [Parameter(Mandatory = $true)][object]$ExpectedDiagnosticCounts,
    [AllowNull()][object]$ExpectedActivityFixture
  )
  Clear-CurrentScenario
  Assert-Condition -Condition ([string]$Manifest.RunStatus -ceq "running") -Code "phase_completion_run_not_active"
  Assert-Condition -Condition ($Phase -cne "PHASE_06_FINAL_POSTCHECK") -Code "phase_completion_requires_evidence_finalizer"
  Assert-Condition -Condition ([string]$Manifest.ActivePhase -ceq $Phase) -Code "phase_completion_active_phase_rejected"
  Assert-Condition -Condition ($null -eq $Manifest.ActiveScenario) -Code "phase_completion_active_scenario_rejected"
  Assert-Condition -Condition ([string]$Manifest.RunStatus -cne "rejected" -and -not (Test-Path -LiteralPath $Paths.Failure -PathType Leaf)) -Code "phase_completion_rejected_run_rejected"
  $expectedIds = @(Get-ScenarioIdsThroughPhase -Phase $Phase)
  $observedIds = @($ApprovedResults | ForEach-Object { [string]$_.Id })
  Assert-Condition -Condition ($observedIds.Count -eq @($observedIds | Sort-Object -Unique).Count) -Code "phase_completion_duplicate_result_rejected"
  Assert-Condition -Condition ((@($observedIds | Sort-Object) -join "|") -ceq (@($expectedIds | Sort-Object) -join "|")) -Code "phase_completion_scenario_set_rejected"
  foreach ($result in $ApprovedResults) {
    $assertions = @(Get-AssertionProperties -Assertions $result.Assertions)
    Assert-Condition -Condition ($assertions.Count -gt 0 -and @($assertions | Where-Object { -not ($_.Value -is [bool]) -or $_.Value -ne $true }).Count -eq 0) -Code "phase_completion_assertion_rejected"
  }
  Assert-ExpectedDiagnosticCountsShape -Counts $ExpectedDiagnosticCounts
  $canonicalCounts = Get-ExpectedDiagnosticCountsForPhase -Phase $Phase
  foreach ($key in @(
    "FixturePeriods", "Activities", "AuditEvents", "OpenWorkers", "GrantedSem01AdvisoryLocks",
    "WaitingSem01AdvisoryLocks", "TotalSem01AdvisoryLocks", "TransientWorkerSqlFiles", "TemporaryObjects"
  )) {
    Assert-Condition -Condition ($ExpectedDiagnosticCounts.$key -eq $canonicalCounts.$key) -Code ("phase_completion_count_rejected_" + $key.ToLowerInvariant())
  }
  Assert-ExpectedActivityFixtureShape -Fixture $ExpectedActivityFixture
  if ($Phase -ceq "PHASE_02_INSTALLATION_MATRIX") {
    Assert-Condition -Condition ($null -ne $ExpectedActivityFixture -and [string]$Manifest.InstallationFixtureId -ceq [string]$ExpectedActivityFixture.Id) -Code "phase02_expected_activity_fixture_rejected"
  }
  else {
    Assert-Condition -Condition ($null -eq $ExpectedActivityFixture -and $null -eq $Manifest.InstallationFixtureId) -Code "completed_phase_activity_fixture_rejected"
  }
  $pidFilePids = @(Get-WorkerPidManifestValues -RunDirectory $Paths.Root)
  Assert-WorkerPidSetsAgree -ManifestPids @($Manifest.ActiveWorkerPids) -PidFilePids $pidFilePids
  Assert-Condition -Condition (@($Manifest.ActiveWorkerPids).Count -eq 0 -and $pidFilePids.Count -eq 0) -Code "phase_completion_workers_active"
  $Manifest.CompletedPhase = $Phase
  $Manifest.ExpectedDatabaseState = $ExpectedDatabaseState
  $Manifest.ApprovedScenarios = @($ApprovedResults | ForEach-Object { $_.Id })
  $Manifest.ApprovedScenarioResults = @($ApprovedResults | ForEach-Object {
    [ordered]@{ Id = $_.Id; Outcome = $_.Outcome; Assertions = $_.Assertions; CompletedAtUtc = $_.CompletedAtUtc }
  })
  $Manifest.ActiveWorkerPids = @()
  $Manifest.ActivePhase = $null
  $Manifest.ActiveScenario = $null
  $Manifest.ExpectedDiagnosticCounts = $ExpectedDiagnosticCounts
  $Manifest.ExpectedActivityFixture = $ExpectedActivityFixture
  $Manifest.RunStatus = "ready"
  Write-Manifest -Paths $Paths -Manifest $Manifest
}

function ConvertTo-FingerprintRecord {
  param([Parameter(Mandatory = $true)][object]$Fingerprint)
  return [ordered]@{
    State = $Fingerprint.State
    PeriodHash = $Fingerprint.PeriodHash
    AuthorityHash = $Fingerprint.AuthorityHash
    AssignmentHash = $Fingerprint.AssignmentHash
    Ms20CandidateCount = $Fingerprint.Ms20CandidateCount
    Ms20CandidateSetHash = $Fingerprint.Ms20CandidateSetHash
    ResolverHash = $Fingerprint.ResolverHash
    BoundaryContractHash = $Fingerprint.BoundaryContractHash
    FunctionInventoryCount = $Fingerprint.FunctionInventoryCount
    FunctionInventoryHash = $Fingerprint.FunctionInventoryHash
    ExpectedTriggerMatchCount = $Fingerprint.ExpectedTriggerMatchCount
    TriggerInventoryHash = $Fingerprint.TriggerInventoryHash
    ConstraintInventoryHash = $Fingerprint.ConstraintInventoryHash
    AuditConstraintCount = $Fingerprint.AuditConstraintCount
    IndexInventoryHash = $Fingerprint.IndexInventoryHash
    TableSecurityHash = $Fingerprint.TableSecurityHash
    RoutineAclHash = $Fingerprint.RoutineAclHash
    NonexistentHelperCount = $Fingerprint.NonexistentHelperCount
    CalendarLockHelperCount = $Fingerprint.CalendarLockHelperCount
    CompleteTriggerInventoryValid = $Fingerprint.CompleteTriggerInventoryValid
    ActivitiesConstraintInventoryValid = $Fingerprint.ActivitiesConstraintInventoryValid
    PeriodConstraintInventoryValid = $Fingerprint.PeriodConstraintInventoryValid
    CompleteAuditConstraintInventoryValid = $Fingerprint.CompleteAuditConstraintInventoryValid
    CompleteIndexInventoryValid = $Fingerprint.CompleteIndexInventoryValid
    TableAclContractValid = $Fingerprint.TableAclContractValid
    RlsContractValid = $Fingerprint.RlsContractValid
    PolicyContractValid = $Fingerprint.PolicyContractValid
  }
}

function Assert-FingerprintPreserved {
  param(
    [Parameter(Mandatory = $true)][object]$Observed,
    [Parameter(Mandatory = $true)][object]$Expected,
    [switch]$IncludeResolver,
    [switch]$IncludeBoundaryContract
  )
  Assert-Condition -Condition ($Observed.PeriodHash -ceq $Expected.PeriodHash) -Code "canonical_period_fingerprint_rejected"
  Assert-Condition -Condition ($Observed.AuthorityHash -ceq $Expected.AuthorityHash) -Code "authority_fingerprint_rejected"
  Assert-Condition -Condition ($Observed.AssignmentHash -ceq $Expected.AssignmentHash) -Code "assignment_fingerprint_rejected"
  Assert-Condition -Condition ($Observed.Ms20CandidateCount -eq $Expected.Ms20CandidateCount -and
    $Observed.Ms20CandidateSetHash -ceq $Expected.Ms20CandidateSetHash) -Code "ms20_candidate_set_fingerprint_rejected"
  if ($IncludeResolver) {
    Assert-Condition -Condition ($Observed.ResolverHash -ceq $Expected.ResolverHash) -Code "resolver_fingerprint_rejected"
  }
  if ($IncludeBoundaryContract) {
    Assert-Condition -Condition ($Observed.BoundaryContractHash -ceq $Expected.BoundaryContractHash) -Code "boundary_contract_fingerprint_rejected"
    Assert-Condition -Condition ($Observed.FunctionInventoryCount -eq $Expected.FunctionInventoryCount -and $Observed.FunctionInventoryHash -ceq $Expected.FunctionInventoryHash) -Code "function_inventory_fingerprint_rejected"
    Assert-Condition -Condition ($Observed.ExpectedTriggerMatchCount -eq $Expected.ExpectedTriggerMatchCount -and $Observed.TriggerInventoryHash -ceq $Expected.TriggerInventoryHash) -Code "trigger_inventory_fingerprint_rejected"
    Assert-Condition -Condition ($Observed.ConstraintInventoryHash -ceq $Expected.ConstraintInventoryHash -and $Observed.AuditConstraintCount -eq $Expected.AuditConstraintCount) -Code "constraint_inventory_fingerprint_rejected"
    Assert-Condition -Condition ($Observed.IndexInventoryHash -ceq $Expected.IndexInventoryHash) -Code "index_inventory_fingerprint_rejected"
    Assert-Condition -Condition ($Observed.TableSecurityHash -ceq $Expected.TableSecurityHash) -Code "table_security_fingerprint_rejected"
    Assert-Condition -Condition ($Observed.RoutineAclHash -ceq $Expected.RoutineAclHash) -Code "routine_acl_fingerprint_rejected"
    Assert-Condition -Condition ($Observed.CompleteTriggerInventoryValid -and $Observed.ActivitiesConstraintInventoryValid -and
      $Observed.PeriodConstraintInventoryValid -and $Observed.CompleteAuditConstraintInventoryValid -and $Observed.CompleteIndexInventoryValid -and
      $Observed.TableAclContractValid -and $Observed.RlsContractValid -and $Observed.PolicyContractValid) -Code "boundary_inventory_validity_rejected"
    Assert-Condition -Condition ($Observed.NonexistentHelperCount -eq $Expected.NonexistentHelperCount -and $Observed.CalendarLockHelperCount -eq $Expected.CalendarLockHelperCount) -Code "boundary_helper_inventory_rejected"
  }
}

function Invoke-ExactRepositorySqlFile {
  param(
    [Parameter(Mandatory = $true)][object]$Connection,
    [Parameter(Mandatory = $true)][string]$PsqlPath,
    [Parameter(Mandatory = $true)][string]$RepositorySqlFile,
    [Parameter(Mandatory = $true)][string]$ApplicationName,
    [Parameter(Mandatory = $true)][string]$RunDirectory,
    [ValidateSet("read committed", "repeatable read")][string]$DefaultIsolation = "read committed"
  )
  $before = Get-Sha256 -Path $RepositorySqlFile
  $result = Invoke-PsqlFile -Connection $Connection -PsqlPath $PsqlPath -SqlFile $RepositorySqlFile -ApplicationName $ApplicationName -RunDirectory $RunDirectory -DefaultIsolation $DefaultIsolation -StatementTimeoutMilliseconds 180000 -LockTimeoutMilliseconds 60000 -ProcessTimeoutMilliseconds $script:RepositorySqlProcessTimeoutMilliseconds -KeepRawLogs -DeleteSqlFileOnCompletion $false -EmitSessionIsolationMarker -EmitRepositoryFileCompletedMarker
  Assert-PsqlApproved -Result $result -FailureCode "repository_sql_execution_rejected"
  [void](Get-ExactRepositoryFileCompletedMarker -Result $result)
  Assert-Condition -Condition ((Get-Sha256 -Path $RepositorySqlFile) -eq $before) -Code "repository_sql_file_changed" -FailureClass "source_integrity_rejection"
  Assert-ProtectedArtifacts
  return $result
}

function Invoke-ExactRepositorySqlFileResult {
  param(
    [Parameter(Mandatory = $true)][object]$Connection,
    [Parameter(Mandatory = $true)][string]$PsqlPath,
    [Parameter(Mandatory = $true)][string]$RepositorySqlFile,
    [Parameter(Mandatory = $true)][string]$ApplicationName,
    [Parameter(Mandatory = $true)][string]$RunDirectory,
    [ValidateSet("read committed", "repeatable read")][string]$DefaultIsolation = "read committed",
    [int]$LockTimeoutMilliseconds = 60000
  )
  $before = Get-Sha256 -Path $RepositorySqlFile
  $result = Invoke-PsqlFile -Connection $Connection -PsqlPath $PsqlPath -SqlFile $RepositorySqlFile -ApplicationName $ApplicationName -RunDirectory $RunDirectory -DefaultIsolation $DefaultIsolation -StatementTimeoutMilliseconds 180000 -LockTimeoutMilliseconds $LockTimeoutMilliseconds -ProcessTimeoutMilliseconds $script:RepositorySqlProcessTimeoutMilliseconds -KeepRawLogs -DeleteSqlFileOnCompletion $false -EmitSessionIsolationMarker
  Assert-Condition -Condition ((Get-Sha256 -Path $RepositorySqlFile) -eq $before) -Code "repository_sql_file_changed" -FailureClass "source_integrity_rejection"
  Assert-ProtectedArtifacts
  return $result
}

function Wait-ForObserverCondition {
  param(
    [Parameter(Mandatory = $true)][scriptblock]$Probe,
    [Parameter(Mandatory = $true)][string]$FailureCode,
    [ValidateRange(1, 600000)][int]$TimeoutMilliseconds = $script:ObserverTimeoutMilliseconds,
    [ValidateRange(1, 600000)][int]$ProbeTimeoutMilliseconds = $script:ObserverProbeProcessTimeoutMilliseconds
  )
  Assert-Condition -Condition ($FailureCode -cmatch '^[a-z0-9]+(?:_[a-z0-9]+)*$') -Code "observer_failure_context_rejected" -FailureClass "source_integrity_rejection"
  $observerStartedTimestamp = Get-MonotonicTimestamp
  $attemptCount = 0
  while ($true) {
    $probeStartedTimestamp = Get-MonotonicTimestamp
    $elapsedBeforeProbe = Get-MonotonicElapsedMilliseconds -StartTimestamp $observerStartedTimestamp -EndTimestamp $probeStartedTimestamp
    if ($elapsedBeforeProbe -ge $TimeoutMilliseconds) {
      Throw-StableFailure -Code "observer_deadline_rejected" -FailureClass "unexpected_timeout"
    }
    $attemptCount++
    try {
      $probeResult = & $Probe
    }
    catch {
      Throw-StableFailure -Code "observer_probe_failed" -FailureClass "worker_crash"
    }
    $probeCompletedTimestamp = Get-MonotonicTimestamp
    $probeElapsedMilliseconds = Get-MonotonicElapsedMilliseconds -StartTimestamp $probeStartedTimestamp -EndTimestamp $probeCompletedTimestamp
    $totalElapsedMilliseconds = Get-MonotonicElapsedMilliseconds -StartTimestamp $observerStartedTimestamp -EndTimestamp $probeCompletedTimestamp
    Assert-ObserverProbeResultShape -ProbeResult $probeResult
    $decision = Resolve-ObserverProbeOutcome -Satisfied ([bool]$probeResult.Satisfied) -Evidence $probeResult.Evidence `
      -TotalElapsedMilliseconds $totalElapsedMilliseconds -ProbeElapsedMilliseconds $probeElapsedMilliseconds `
      -AttemptCount $attemptCount -TimeoutMilliseconds $TimeoutMilliseconds -ProbeTimeoutMilliseconds $ProbeTimeoutMilliseconds `
      -CompletedMonotonicTimestamp $probeCompletedTimestamp -ConditionCode $FailureCode
    if ($null -ne $decision) { return $decision }
    if (Test-ObjectProperty -Value $probeResult -Name "TerminalFailureCode") {
      $terminalFailureCode = [string]$probeResult.TerminalFailureCode
      if (-not [string]::IsNullOrWhiteSpace($terminalFailureCode)) {
        Throw-StableFailure -Code $terminalFailureCode -FailureClass "worker_crash"
      }
    }
    Start-Sleep -Milliseconds $script:ObserverPollMilliseconds
  }
}

function Assert-ObserverProbeResultShape {
  param([AllowNull()][object]$ProbeResult)
  if ($null -eq $ProbeResult -or -not (Test-ObjectProperty -Value $ProbeResult -Name "Satisfied") -or
    -not (Test-ObjectProperty -Value $ProbeResult -Name "Evidence")) {
    Throw-StableFailure -Code "observer_probe_failed" -FailureClass "worker_crash"
  }
}

function Resolve-ObserverProbeOutcome {
  param(
    [Parameter(Mandatory = $true)][bool]$Satisfied,
    [AllowNull()][object]$Evidence,
    [Parameter(Mandatory = $true)][double]$TotalElapsedMilliseconds,
    [Parameter(Mandatory = $true)][double]$ProbeElapsedMilliseconds,
    [Parameter(Mandatory = $true)][ValidateRange(1, 2147483647)][int]$AttemptCount,
    [Parameter(Mandatory = $true)][ValidateRange(1, 600000)][int]$TimeoutMilliseconds,
    [Parameter(Mandatory = $true)][ValidateRange(1, 600000)][int]$ProbeTimeoutMilliseconds,
    [Parameter(Mandatory = $true)][long]$CompletedMonotonicTimestamp,
    [Parameter(Mandatory = $true)][string]$ConditionCode
  )
  Assert-Condition -Condition ($TotalElapsedMilliseconds -ge 0 -and $ProbeElapsedMilliseconds -ge 0 -and
    $ProbeElapsedMilliseconds -le $TotalElapsedMilliseconds) -Code "observer_elapsed_contract_rejected" -FailureClass "source_integrity_rejection"
  if ($Satisfied) {
    if ($ProbeElapsedMilliseconds -gt $ProbeTimeoutMilliseconds -or $TotalElapsedMilliseconds -gt $TimeoutMilliseconds) {
      Throw-StableFailure -Code "observer_probe_late_success_rejected" -FailureClass "unexpected_timeout"
    }
    return [pscustomobject]@{
      Satisfied = $true
      TotalElapsedMilliseconds = [double]$TotalElapsedMilliseconds
      ProbeElapsedMilliseconds = [double]$ProbeElapsedMilliseconds
      AttemptCount = [int]$AttemptCount
      Evidence = $Evidence
      CompletedMonotonicTimestamp = [long]$CompletedMonotonicTimestamp
      ConditionCode = $ConditionCode
    }
  }
  if ($ProbeElapsedMilliseconds -gt $ProbeTimeoutMilliseconds) {
    Throw-StableFailure -Code "observer_probe_failed" -FailureClass "unexpected_timeout"
  }
  if ($TotalElapsedMilliseconds -ge $TimeoutMilliseconds) {
    Throw-StableFailure -Code "observer_condition_not_observed" -FailureClass "unexpected_timeout"
  }
  return $null
}

function Assert-GenericObserverContractFixtures {
  $evidence = [pscustomobject]@{ Marker = "structured_fixture"; ExactHolderCount = 1; ExactWaiterCount = 1 }
  $timely = Resolve-ObserverProbeOutcome -Satisfied $true -Evidence $evidence -TotalElapsedMilliseconds 999 `
    -ProbeElapsedMilliseconds 999 -AttemptCount 1 -TimeoutMilliseconds 1000 -ProbeTimeoutMilliseconds 1000 `
    -CompletedMonotonicTimestamp 999 -ConditionCode "fixture_timely_true"
  Assert-Condition -Condition ($timely.Satisfied -and $timely.TotalElapsedMilliseconds -eq 999 -and
    $timely.ProbeElapsedMilliseconds -eq 999 -and $timely.AttemptCount -eq 1 -and
    $timely.Evidence.Marker -ceq "structured_fixture") -Code "observer_timely_true_fixture_rejected"
  Assert-LocalStableFailure -ExpectedCode "observer_probe_late_success_rejected" -Operation {
    [void](Resolve-ObserverProbeOutcome -Satisfied $true -Evidence $evidence -TotalElapsedMilliseconds 1001 `
      -ProbeElapsedMilliseconds 1001 -AttemptCount 1 -TimeoutMilliseconds 1000 -ProbeTimeoutMilliseconds 1000 `
      -CompletedMonotonicTimestamp 1001 -ConditionCode "fixture_late_true")
  }
  $firstFalse = Resolve-ObserverProbeOutcome -Satisfied $false -Evidence $null -TotalElapsedMilliseconds 400 `
    -ProbeElapsedMilliseconds 100 -AttemptCount 1 -TimeoutMilliseconds 1000 -ProbeTimeoutMilliseconds 500 `
    -CompletedMonotonicTimestamp 400 -ConditionCode "fixture_false_then_true"
  Assert-Condition -Condition ($null -eq $firstFalse) -Code "observer_false_before_deadline_fixture_rejected"
  $secondTrue = Resolve-ObserverProbeOutcome -Satisfied $true -Evidence $evidence -TotalElapsedMilliseconds 999 `
    -ProbeElapsedMilliseconds 199 -AttemptCount 2 -TimeoutMilliseconds 1000 -ProbeTimeoutMilliseconds 500 `
    -CompletedMonotonicTimestamp 999 -ConditionCode "fixture_false_then_true"
  Assert-Condition -Condition ($secondTrue.Satisfied -and $secondTrue.AttemptCount -eq 2) -Code "observer_false_then_timely_true_fixture_rejected"
  Assert-LocalStableFailure -ExpectedCode "observer_probe_late_success_rejected" -Operation {
    [void](Resolve-ObserverProbeOutcome -Satisfied $true -Evidence $evidence -TotalElapsedMilliseconds 1001 `
      -ProbeElapsedMilliseconds 201 -AttemptCount 2 -TimeoutMilliseconds 1000 -ProbeTimeoutMilliseconds 500 `
      -CompletedMonotonicTimestamp 1001 -ConditionCode "fixture_false_then_late_true")
  }
  Assert-LocalStableFailure -ExpectedCode "observer_probe_failed" -Operation {
    Assert-ObserverProbeResultShape -ProbeResult ([pscustomobject]@{ Satisfied = $true })
  }
  Assert-ObserverProbeResultShape -ProbeResult ([pscustomobject]@{ Satisfied = $true; Evidence = $evidence })
}

function Test-Ms20ReleaseEligible {
  param(
    [Parameter(Mandatory = $true)][bool]$StageAObserved,
    [Parameter(Mandatory = $true)][bool]$TemporaryAssignmentRemovalCommitted,
    [Parameter(Mandatory = $true)][bool]$PostRemovalBlockedStateObserved
  )
  return ($StageAObserved -and $TemporaryAssignmentRemovalCommitted -and $PostRemovalBlockedStateObserved)
}

function Assert-RuntimeObservationContractFixtures {
  $exactPair = [pscustomobject]@{
    ExactHolderCount = 1; ExactWaiterCount = 1; HolderAdvisoryGranted = $true; WaiterAdvisoryUnGranted = $true
    HolderAlive = $true; WaiterAlive = $true; HolderWaiterPidsDiffer = $true
    WaiterActivitiesRowExclusiveGranted = $true; HolderActivitiesConflictAbsent = $true
    ExpectedHolderMatched = $true; ExpectedWaiterMatched = $true; TemporaryAssignmentAbsent = $true
    InternalHolderBackendPid = 101; InternalWaiterBackendPid = 202
  }
  Assert-Condition -Condition (Test-ExactAdvisoryPairEvidence -Evidence $exactPair -RequireWaiterActivitiesRelationLock -RequireTemporaryAssignmentAbsent) -Code "advisory_pair_positive_fixture_rejected"
  foreach ($mutation in @(
    [pscustomobject]@{ Name = "missing_holder"; Property = "ExactHolderCount"; Value = 0 },
    [pscustomobject]@{ Name = "duplicate_holder"; Property = "ExactHolderCount"; Value = 2 },
    [pscustomobject]@{ Name = "missing_granted_holder"; Property = "HolderAdvisoryGranted"; Value = $false },
    [pscustomobject]@{ Name = "missing_ungranted_waiter"; Property = "WaiterAdvisoryUnGranted"; Value = $false },
    [pscustomobject]@{ Name = "missing_waiter_relation"; Property = "WaiterActivitiesRowExclusiveGranted"; Value = $false },
    [pscustomobject]@{ Name = "holder_relation_conflict"; Property = "HolderActivitiesConflictAbsent"; Value = $false },
    [pscustomobject]@{ Name = "same_pid"; Property = "InternalWaiterBackendPid"; Value = 101 }
  )) {
    $candidate = $exactPair.PSObject.Copy()
    $candidate.PSObject.Properties[$mutation.Property].Value = $mutation.Value
    if ($mutation.Name -ceq "same_pid") { $candidate.HolderWaiterPidsDiffer = $false }
    Assert-Condition -Condition (-not (Test-ExactAdvisoryPairEvidence -Evidence $candidate -RequireWaiterActivitiesRelationLock -RequireTemporaryAssignmentAbsent)) -Code ("advisory_pair_" + $mutation.Name + "_fixture_rejected")
  }
  Assert-Condition -Condition (Test-Ms20ReleaseEligible -StageAObserved $true -TemporaryAssignmentRemovalCommitted $true -PostRemovalBlockedStateObserved $true) -Code "ms20_release_positive_fixture_rejected"
  Assert-Condition -Condition (-not (Test-Ms20ReleaseEligible -StageAObserved $true -TemporaryAssignmentRemovalCommitted $true -PostRemovalBlockedStateObserved $false)) -Code "ms20_release_without_post_removal_observation_fixture_rejected"
  $stageFixture = [pscustomobject]@{ StageState = "started" }
  Assert-LocalStableFailure -ExpectedCode "staged_worker_stage_b_rejected" -Operation {
    [void](Get-StagedWorkerNextState -CurrentState $stageFixture.StageState -Stage "B" -ProcessHasExited $false)
  }
  $stageFixture.StageState = Get-StagedWorkerNextState -CurrentState $stageFixture.StageState -Stage "A" -ProcessHasExited $false
  Confirm-StagedWorkerStageA -Worker $stageFixture -ProcessHasExited $false
  $stageFixture.StageState = Get-StagedWorkerNextState -CurrentState $stageFixture.StageState -Stage "B" -ProcessHasExited $false
  Assert-LocalStableFailure -ExpectedCode "staged_worker_stage_b_rejected" -Operation {
    [void](Get-StagedWorkerNextState -CurrentState $stageFixture.StageState -Stage "B" -ProcessHasExited $false)
  }
  $sanitized = ConvertTo-SanitizedAdvisoryPairEvidence -Evidence $exactPair
  $sanitizedLines = @($sanitized.PSObject.Properties | ForEach-Object { "PAIR_$($_.Name.ToUpperInvariant())|$($_.Value)" })
  Assert-Condition -Condition (-not (Test-ForbiddenEvidence -Lines $sanitizedLines)) -Code "runtime_observer_sanitization_fixture_rejected"
}

function Assert-AdvisoryHolderReadinessFixtures {
  $exactEvidence = [pscustomobject]@{
    Satisfied = $true
    ExactHolderCount = 1
    HolderAlive = $true
    HolderAdvisoryGranted = $true
    ExactGrantedHolderCount = 1
    InternalHolderBackendPid = 101
    LocalHolderProcessAlive = $true
  }
  $exactObservation = [pscustomobject]@{ Satisfied = $true; Evidence = $exactEvidence }

  foreach ($mutation in @(
    [pscustomobject]@{ Name = "holder_not_ready"; Property = "Satisfied"; Value = $false },
    [pscustomobject]@{ Name = "duplicate_holder_sessions"; Property = "ExactHolderCount"; Value = 2 },
    [pscustomobject]@{ Name = "holder_without_granted_advisory"; Property = "HolderAdvisoryGranted"; Value = $false },
    [pscustomobject]@{ Name = "duplicate_granted_holder"; Property = "ExactGrantedHolderCount"; Value = 2 },
    [pscustomobject]@{ Name = "holder_process_exited"; Property = "LocalHolderProcessAlive"; Value = $false }
  )) {
    $candidateEvidence = $exactEvidence.PSObject.Copy()
    $candidateEvidence.PSObject.Properties[$mutation.Property].Value = $mutation.Value
    $candidateObservation = [pscustomobject]@{ Satisfied = [bool]$candidateEvidence.Satisfied; Evidence = $candidateEvidence }
    $waiterStartCount = 0
    Assert-LocalStableFailure -ExpectedCode "advisory_holder_readiness_not_observed" -Operation {
      [void](Start-AdvisoryWaiterAfterHolderReady -HolderObservation $candidateObservation -WaiterStartCount ([ref]$waiterStartCount) -StartOperation {
        [pscustomobject]@{ Fixture = "waiter_must_not_start" }
      })
    }
    Assert-Condition -Condition ($waiterStartCount -eq 0) -Code ("advisory_readiness_" + $mutation.Name + "_fixture_rejected")
  }

  $successfulWaiterStartCount = 0
  $successfulWorker = Start-AdvisoryWaiterAfterHolderReady -HolderObservation $exactObservation `
    -WaiterStartCount ([ref]$successfulWaiterStartCount) -StartOperation { [pscustomobject]@{ Fixture = "waiter_started_once" } }
  Assert-Condition -Condition ($successfulWaiterStartCount -eq 1 -and $successfulWorker.Fixture -ceq "waiter_started_once") `
    -Code "advisory_readiness_exact_holder_fixture_rejected"
  Assert-LocalStableFailure -ExpectedCode "advisory_waiter_start_count_rejected" -Operation {
    [void](Start-AdvisoryWaiterAfterHolderReady -HolderObservation $exactObservation `
      -WaiterStartCount ([ref]$successfulWaiterStartCount) -StartOperation { [pscustomobject]@{ Fixture = "duplicate_waiter" } })
  }

  $samePair = [pscustomobject]@{ ExpectedHolderMatched = $true; InternalHolderBackendPid = 101 }
  $changedPair = [pscustomobject]@{ ExpectedHolderMatched = $false; InternalHolderBackendPid = 202 }
  Assert-Condition -Condition (Test-SameAdvisoryHolderObservedInPair -HolderObservation $exactObservation -PairEvidence $samePair) `
    -Code "advisory_readiness_same_holder_fixture_rejected"
  Assert-Condition -Condition (-not (Test-SameAdvisoryHolderObservedInPair -HolderObservation $exactObservation -PairEvidence $changedPair)) `
    -Code "advisory_readiness_changed_holder_fixture_rejected"

  $pairDefinition = [string](Get-Command Invoke-AdvisoryWaitPair -CommandType Function).Definition
  $wallDefinition = [string](Get-Command Invoke-WallClockScenarios -CommandType Function).Definition
  foreach ($definition in @($pairDefinition, $wallDefinition)) {
    Assert-Condition -Condition ($definition -notmatch 'Start-Sleep\s+-Milliseconds\s+(?:700|800)') `
      -Code "advisory_readiness_fixed_sleep_fixture_rejected"
    $readinessIndex = $definition.IndexOf("Wait-ForExactAdvisoryHolder", [System.StringComparison]::Ordinal)
    $waiterIndex = $definition.IndexOf("Start-AdvisoryWaiterAfterHolderReady", [System.StringComparison]::Ordinal)
    Assert-Condition -Condition ($readinessIndex -ge 0 -and $waiterIndex -gt $readinessIndex) `
      -Code "advisory_readiness_start_order_fixture_rejected"
  }
}

function Assert-Db21AdvisoryStagingAndOwnershipFixtures {
  $granted = [pscustomobject]@{ LockType = "advisory"; ClassId = 1397310541; ObjId = 1101; ObjSubId = 2; Granted = $true }
  $waiting = [pscustomobject]@{ LockType = "advisory"; ClassId = 1397310541; ObjId = 1101; ObjSubId = 2; Granted = $false }
  Assert-Condition -Condition (Test-ExactSem01AdvisoryLockRow -Row $granted -ExpectedGranted $true) -Code "db21_exact_granted_advisory_fixture_rejected"
  Assert-Condition -Condition (Test-ExactSem01AdvisoryLockRow -Row $waiting -ExpectedGranted $false) -Code "db21_exact_waiting_advisory_fixture_rejected"
  $wrongObjSubId = $granted.PSObject.Copy(); $wrongObjSubId.ObjSubId = 1
  Assert-Condition -Condition (-not (Test-ExactSem01AdvisoryLockRow -Row $wrongObjSubId -ExpectedGranted $true)) -Code "db21_objsubid_one_fixture_rejected"
  $missingObjSubId = [pscustomobject]@{ LockType = "advisory"; ClassId = 1397310541; ObjId = 1101; Granted = $true }
  Assert-Condition -Condition (-not (Test-ExactSem01AdvisoryLockRow -Row $missingObjSubId -ExpectedGranted $true)) -Code "db21_missing_objsubid_fixture_rejected"

  $cleanCounts = [pscustomobject]@{ GrantedSem01AdvisoryLocks = 0; WaitingSem01AdvisoryLocks = 0; TotalSem01AdvisoryLocks = 0; TransientWorkerSqlFiles = 0 }
  Assert-Condition -Condition (Test-RuntimeDiagnosticCountsClean -Counts $cleanCounts) -Code "db21_zero_runtime_residue_fixture_rejected"
  foreach ($mutation in @(
    [pscustomobject]@{ Property = "GrantedSem01AdvisoryLocks"; Code = "db21_granted_residue_fixture_rejected" },
    [pscustomobject]@{ Property = "WaitingSem01AdvisoryLocks"; Code = "db21_waiting_residue_fixture_rejected" },
    [pscustomobject]@{ Property = "TransientWorkerSqlFiles"; Code = "db21_transient_sql_residue_fixture_rejected" }
  )) {
    $candidate = $cleanCounts.PSObject.Copy(); $candidate.PSObject.Properties[$mutation.Property].Value = 1; $candidate.TotalSem01AdvisoryLocks = $(if ($mutation.Property -like "*AdvisoryLocks") { 1 } else { 0 })
    Assert-Condition -Condition (-not (Test-RuntimeDiagnosticCountsClean -Counts $candidate)) -Code $mutation.Code
  }

  Assert-Condition -Condition (Test-StagedRuntimeHolderReleaseEligible -Policy "MS11_MS12" -OperationReadyObserved $true -ExactPairObserved $true -WaiterCollected $true -WaiterSqlState "55P03") -Code "db21_55p03_release_fixture_rejected"
  Assert-Condition -Condition (-not (Test-StagedRuntimeHolderReleaseEligible -Policy "MS11_MS12" -OperationReadyObserved $true -ExactPairObserved $true)) -Code "db21_release_before_55p03_fixture_rejected"
  Assert-Condition -Condition (-not (Test-StagedRuntimeHolderReleaseEligible -Policy "MS11_MS12" -OperationReadyObserved $true -ExactPairObserved $true -WaiterCollected $true -WaiterSqlState "00000" -WaiterSucceeded $true)) -Code "db21_waiter_success_before_release_fixture_rejected"
  Assert-Condition -Condition (-not (Test-StagedRuntimeHolderReleaseEligible -Policy "MS13_MS17" -OperationReadyObserved $true -ExactPairObserved $false)) -Code "db21_release_before_pair_fixture_rejected"
  $releaseBeforeExit = Test-StagedRuntimeHolderReleaseEligible -Policy "MS13_MS17" -OperationReadyObserved $true -ExactPairObserved $true -HolderProcessHasExited $false
  $releaseAfterExit = Test-StagedRuntimeHolderReleaseEligible -Policy "MS13_MS17" -OperationReadyObserved $true -ExactPairObserved $true -HolderProcessHasExited $true
  Assert-Condition -Condition ($releaseBeforeExit -and $releaseAfterExit) -Code "db21_process_exit_chronology_fixture_rejected"

  $pairDefinition = [string](Get-Command Invoke-AdvisoryWaitPair -CommandType Function).Definition
  $wallDefinition = [string](Get-Command Invoke-WallClockScenarios -CommandType Function).Definition
  $holderDefinition = [string](Get-Command Start-StagedRuntimeAdvisoryHolder -CommandType Function).Definition
  $calendarStageDefinition = [string](Get-Command Get-CalendarCorrectionHolderStageASql -CommandType Function).Definition
  Assert-Condition -Condition (($holderDefinition + $calendarStageDefinition + $pairDefinition) -notmatch '(?i)pg_sleep\s*\(') -Code "db21_runtime_fixed_sleep_fixture_rejected"
  foreach ($definition in @($pairDefinition, $wallDefinition)) {
    $stateIndex = $definition.IndexOf("New-PairedTransientSqlOwnershipState", [System.StringComparison]::Ordinal)
    $tryIndex = $definition.IndexOf("try {", [System.StringComparison]::Ordinal)
    $holderArtifactIndex = $definition.IndexOf("`$holderArtifact = New-SqlFile", [System.StringComparison]::Ordinal)
    $waiterArtifactIndex = $definition.IndexOf("`$waiterArtifact = New-SqlFile", [System.StringComparison]::Ordinal)
    Assert-Condition -Condition ($stateIndex -ge 0 -and $tryIndex -gt $stateIndex -and $holderArtifactIndex -gt $tryIndex -and
      $waiterArtifactIndex -gt $holderArtifactIndex) -Code "db21_paired_sql_ownership_order_fixture_rejected"
    Assert-Condition -Condition ($definition.Contains('Remove-UnownedTransientSqlFile -State') -and
      $definition.Contains('-Role "Holder"') -and $definition.Contains('-Role "Waiter"')) -Code "db21_independent_sql_cleanup_fixture_rejected"
  }
  foreach ($failurePoint in @("holder_file", "waiter_file", "fixture", "holder_start", "completed")) {
    $model = Invoke-SyntheticPairedSqlOwnershipModel -FailurePoint $failurePoint
    Assert-Condition -Condition ($null -eq $model.State.HolderSqlFile -and $null -eq $model.State.WaiterSqlFile -and
      (@($model.RemovalAttempts) -join "|") -ceq "Holder|Waiter" -and -not $model.ProcessLaunched) `
      -Code ("db21_" + $failurePoint + "_sql_lifecycle_fixture_rejected")
  }
  $syntheticOwnership = New-PairedTransientSqlOwnershipState
  $syntheticOwnership.HolderSqlFile = "synthetic_holder.sql"
  Assert-Condition -Condition ($syntheticOwnership.WaiterSqlFile -eq $null -and -not $syntheticOwnership.HolderSqlOwnedByWorker) -Code "db21_second_file_failure_ownership_fixture_rejected"
  $syntheticOwnership.WaiterSqlFile = "synthetic_waiter.sql"
  $syntheticOwnership.HolderSqlOwnedByWorker = $true
  $syntheticOwnership.HolderWorker = [pscustomobject]@{ Process = [pscustomobject]@{ HasExited = $false } }
  Assert-Condition -Condition ($syntheticOwnership.HolderSqlOwnedByWorker -and -not $syntheticOwnership.WaiterSqlOwnedByWorker) -Code "db21_worker_owned_file_fixture_rejected"
  $attempts = New-Object System.Collections.ArrayList
  $cleanup = Invoke-OrchestrationCleanup -CleanupOperations @(
    [pscustomobject]@{ Name = "FIXTURE_HOLDER_REMOVE"; Operation = { [void]$attempts.Add("holder"); throw "fixture_failure" } },
    [pscustomobject]@{ Name = "FIXTURE_WAITER_REMOVE"; Operation = { [void]$attempts.Add("waiter") } }
  )
  Assert-Condition -Condition (-not $cleanup.Succeeded -and (@($attempts) -join "|") -ceq "holder|waiter") -Code "db21_independent_cleanup_attempt_fixture_rejected"
}

function Invoke-Db22ExpectedNewSqlFileFailure {
  param(
    [Parameter(Mandatory = $true)][string]$RunDirectory,
    [Parameter(Mandatory = $true)][string]$Label,
    [Parameter(Mandatory = $true)][string]$Sql,
    [Parameter(Mandatory = $true)][ValidateSet("precreated_partial", "writer_construction", "write", "flush", "disposal", "content_mismatch", "hash_mismatch", "removal_failure")][string]$Fault,
    [Parameter(Mandatory = $true)][string]$ExpectedCode
  )
  $captured = $null
  $script:TransientSqlFixtureFault = $Fault
  try { [void](New-SqlFile -RunDirectory $RunDirectory -Label $Label -Sql $Sql -InitialOwner controller) }
  catch { $captured = $_ }
  $script:TransientSqlFixtureFault = $null
  Assert-Condition -Condition ($null -ne $captured -and $captured.Exception.Message -ceq $ExpectedCode) `
    -Code ("db22_" + $Fault + "_error_contract_rejected") -FailureClass "source_integrity_rejection"
  return $captured
}

function New-Db22TransientCleanupState {
  param([Parameter(Mandatory = $true)][string]$Path)
  return [pscustomobject]@{
    Path = $Path
    RemovalAttempted = $false
    RemovalSucceeded = $false
    SecondaryCleanupErrors = @()
  }
}

function Assert-Db22TransientSqlCreationFixtures {
  $originalScenario = $script:CurrentScenario
  $fixtureRoot = [System.IO.Path]::GetFullPath((Join-Path $script:EvidenceRoot ("validate-db22-" + [guid]::NewGuid().ToString("N"))))
  $evidenceRoot = [System.IO.Path]::GetFullPath($script:EvidenceRoot).TrimEnd('\') + '\'
  Assert-Condition -Condition ($fixtureRoot.StartsWith($evidenceRoot, [System.StringComparison]::OrdinalIgnoreCase) -and
    (Split-Path -Leaf $fixtureRoot) -cmatch '^validate-db22-[a-f0-9]{32}$') `
    -Code "db22_fixture_root_rejected" -FailureClass "source_integrity_rejection"
  if (-not (Test-Path -LiteralPath $script:EvidenceRoot -PathType Container)) {
    [void](New-Item -ItemType Directory -Path $script:EvidenceRoot -Force)
  }
  [void](New-Item -ItemType Directory -Path $fixtureRoot)
  $fixtureError = $null
  $fixtureScenario = $null
  $fixtureWorkerStartCount = 0
  try {
    $sql = "  select 1;  "
    $canonicalContent = "select 1;`n"
    $successArtifact = New-SqlFile -RunDirectory $fixtureRoot -Label "success" -Sql $sql -InitialOwner controller
    $successPath = $successArtifact.Path
    $successBytes = [System.IO.File]::ReadAllBytes($successPath)
    $successHasBom = $successBytes.Length -ge 3 -and $successBytes[0] -eq 0xEF -and $successBytes[1] -eq 0xBB -and $successBytes[2] -eq 0xBF
    $strictUtf8 = New-Object System.Text.UTF8Encoding($false, $true)
    Assert-Condition -Condition ($successBytes.Length -gt 0 -and -not $successHasBom -and
      $strictUtf8.GetString($successBytes) -ceq $canonicalContent -and
      (Get-Sha256 -Path $successPath) -ceq (Get-TextSha256 -Text $canonicalContent)) `
      -Code "db22_successful_transient_sql_verification_fixture_rejected"
    $successCleanupState = $successArtifact.OwnershipState
    $successCleanup = Invoke-PsqlDisposableControllerCleanup -State $successCleanupState
    Complete-OrchestrationCleanup -PrimaryError $null -PrimaryScenario $null -CleanupResult $successCleanup `
      -CleanupFailureCode "db22_successful_transient_sql_cleanup_rejected"
    Assert-Condition -Condition ($successCleanupState.AbsenceObserved -and -not (Test-Path -LiteralPath $successPath)) `
      -Code "db22_successful_transient_sql_absence_rejected"

    $holderState = New-PairedTransientSqlOwnershipState
    $holderFailure = Invoke-Db22ExpectedNewSqlFileFailure -RunDirectory $fixtureRoot -Label "holder_partial" -Sql $sql `
      -Fault "precreated_partial" -ExpectedCode "transient_sql_fixture_open_failure"
    Assert-Condition -Condition ($null -ne $holderFailure -and $null -eq $holderState.HolderSqlFile -and
      $null -eq $holderState.WaiterSqlFile -and $fixtureWorkerStartCount -eq 0 -and
      (Get-TransientWorkerSqlFileCount -RunDirectory $fixtureRoot) -eq 0) `
      -Code "db22_holder_partial_file_cleanup_fixture_rejected"

    $waiterState = New-PairedTransientSqlOwnershipState
    $waiterArtifact = New-SqlFile -RunDirectory $fixtureRoot -Label "waiter_holder" -Sql $sql -InitialOwner controller
    $waiterState.HolderSqlFile = $waiterArtifact.Path
    $waiterState.HolderOwnershipState = $waiterArtifact.OwnershipState
    $waiterFailure = Invoke-Db22ExpectedNewSqlFileFailure -RunDirectory $fixtureRoot -Label "waiter_partial" -Sql $sql `
      -Fault "precreated_partial" -ExpectedCode "transient_sql_fixture_open_failure"
    $waiterCleanup = Invoke-OrchestrationCleanup -CleanupOperations @(
      [pscustomobject]@{ Name = "DB22_HOLDER_SQL_REMOVE"; Operation = {
        Remove-UnownedTransientSqlFile -State $waiterState -Role "Holder" -RunDirectory $fixtureRoot
      } },
      [pscustomobject]@{ Name = "DB22_WAITER_SQL_REMOVE"; Operation = {
        Remove-UnownedTransientSqlFile -State $waiterState -Role "Waiter" -RunDirectory $fixtureRoot
      } }
    )
    Complete-OrchestrationCleanup -PrimaryError $null -PrimaryScenario $null -CleanupResult $waiterCleanup `
      -CleanupFailureCode "db22_waiter_surrounding_cleanup_rejected"
    Assert-Condition -Condition ($null -ne $waiterFailure -and $null -eq $waiterState.HolderSqlFile -and
      $null -eq $waiterState.WaiterSqlFile -and $fixtureWorkerStartCount -eq 0 -and
      (Get-TransientWorkerSqlFileCount -RunDirectory $fixtureRoot) -eq 0) `
      -Code "db22_waiter_partial_file_cleanup_fixture_rejected"

    foreach ($faultFixture in @(
      [pscustomobject]@{ Fault = "writer_construction"; ExpectedCode = "transient_sql_fixture_writer_construction_failure" },
      [pscustomobject]@{ Fault = "write"; ExpectedCode = "transient_sql_fixture_write_failure" },
      [pscustomobject]@{ Fault = "flush"; ExpectedCode = "transient_sql_fixture_flush_failure" },
      [pscustomobject]@{ Fault = "content_mismatch"; ExpectedCode = "transient_sql_content_rejected" },
      [pscustomobject]@{ Fault = "hash_mismatch"; ExpectedCode = "transient_sql_sha256_rejected" }
    )) {
      [void](Invoke-Db22ExpectedNewSqlFileFailure -RunDirectory $fixtureRoot -Label ("fault_" + $faultFixture.Fault) `
        -Sql $sql -Fault $faultFixture.Fault -ExpectedCode $faultFixture.ExpectedCode)
      Assert-Condition -Condition ((Get-TransientWorkerSqlFileCount -RunDirectory $fixtureRoot) -eq 0) `
        -Code ("db22_" + $faultFixture.Fault + "_physical_cleanup_fixture_rejected")
    }

    $script:TransientSqlFixtureEvents = New-Object System.Collections.ArrayList
    [void](Invoke-Db22ExpectedNewSqlFileFailure -RunDirectory $fixtureRoot -Label "fault_disposal" -Sql $sql `
      -Fault "disposal" -ExpectedCode "external_file_cleanup_rejected")
    Assert-Condition -Condition ((@($script:TransientSqlFixtureEvents) -join "|") -ceq "writer_dispose_attempted|stream_dispose_attempted" -and
      (Get-TransientWorkerSqlFileCount -RunDirectory $fixtureRoot) -eq 0) -Code "db22_disposal_attempts_and_cleanup_fixture_rejected"
    $script:TransientSqlFixtureEvents = $null

    $previousWarningPreference = $WarningPreference
    $WarningPreference = "SilentlyContinue"
    try {
      $primaryRemovalFailure = Invoke-Db22ExpectedNewSqlFileFailure -RunDirectory $fixtureRoot -Label "removal_primary" -Sql $sql `
        -Fault "removal_failure" -ExpectedCode "transient_sql_fixture_open_failure"
    }
    catch {
      $WarningPreference = $previousWarningPreference
      throw $_
    }
    $WarningPreference = $previousWarningPreference
    $remainingAfterPrimaryRemovalFailure = @(Get-ChildItem -LiteralPath $fixtureRoot -Filter "worker_removal_primary_*.sql" -File)
    Assert-Condition -Condition ($null -ne $primaryRemovalFailure -and $remainingAfterPrimaryRemovalFailure.Count -eq 1) `
      -Code "db22_primary_error_preservation_fixture_rejected"
    $failedRemovalState = New-Db22TransientCleanupState -Path $remainingAfterPrimaryRemovalFailure[0].FullName
    $script:TransientSqlFixtureFault = "removal_failure"
    $previousWarningPreference = $WarningPreference
    $WarningPreference = "SilentlyContinue"
    try { $failedRemovalCleanup = Invoke-TransientSqlPathCleanup -CreationState $failedRemovalState -RunDirectory $fixtureRoot }
    catch {
      $WarningPreference = $previousWarningPreference
      $script:TransientSqlFixtureFault = $null
      throw $_
    }
    $WarningPreference = $previousWarningPreference
    $script:TransientSqlFixtureFault = $null
    Assert-Condition -Condition (-not $failedRemovalCleanup.Succeeded -and -not $failedRemovalState.RemovalSucceeded -and
      @($failedRemovalState.SecondaryCleanupErrors).Count -ge 1 -and (Test-Path -LiteralPath $failedRemovalState.Path -PathType Leaf)) `
      -Code "db22_secondary_cleanup_failure_record_fixture_rejected"
    $caughtPrimary = $null
    try {
      Complete-OrchestrationCleanup -PrimaryError $primaryRemovalFailure -PrimaryScenario $originalScenario `
        -CleanupResult $failedRemovalCleanup -CleanupFailureCode "transient_sql_cleanup_rejected"
    }
    catch { $caughtPrimary = $_ }
    Assert-Condition -Condition ([object]::ReferenceEquals($primaryRemovalFailure, $caughtPrimary) -or
      ($caughtPrimary.Exception.Message -ceq $primaryRemovalFailure.Exception.Message)) -Code "db22_primary_error_replaced_by_cleanup_fixture_rejected"
    $stableCleanupFailure = $null
    try {
      Complete-OrchestrationCleanup -PrimaryError $null -PrimaryScenario $null -CleanupResult $failedRemovalCleanup `
        -CleanupFailureCode "transient_sql_cleanup_rejected"
    }
    catch { $stableCleanupFailure = $_ }
    Assert-Condition -Condition ($null -ne $stableCleanupFailure -and $stableCleanupFailure.Exception.Message -ceq "transient_sql_cleanup_rejected") `
      -Code "db22_successful_primary_failed_removal_fixture_rejected"
    $finalRemovalCleanup = Invoke-TransientSqlPathCleanup -CreationState $failedRemovalState -RunDirectory $fixtureRoot
    Complete-OrchestrationCleanup -PrimaryError $null -PrimaryScenario $null -CleanupResult $finalRemovalCleanup `
      -CleanupFailureCode "db22_final_fixture_removal_rejected"

    Assert-Condition -Condition ((Get-TransientWorkerSqlFileCount -RunDirectory $fixtureRoot) -eq 0) `
      -Code "db22_fixture_transient_sql_residue_rejected"
  }
  catch {
    $fixtureError = $_
    $fixtureScenario = [string]$script:CurrentScenario
  }
  $script:TransientSqlFixtureFault = $null
  $script:TransientSqlFixtureEvents = $null
  $script:CurrentScenario = $originalScenario
  $fixtureCleanup = Invoke-OrchestrationCleanup -CleanupOperations @(
    [pscustomobject]@{ Name = "DB22_FIXTURE_FILES_REMOVE"; Operation = {
      if (Test-Path -LiteralPath $fixtureRoot -PathType Container) {
        foreach ($item in @(Get-ChildItem -LiteralPath $fixtureRoot -File -Force)) {
          Assert-DisposableWorkerSqlPath -SqlFile $item.FullName -RunDirectory $fixtureRoot
          Remove-Item -LiteralPath $item.FullName -Force
        }
      }
    } },
    [pscustomobject]@{ Name = "DB22_FIXTURE_DIRECTORY_REMOVE"; Operation = {
      $validatedRoot = [System.IO.Path]::GetFullPath($fixtureRoot)
      Assert-Condition -Condition ($validatedRoot.StartsWith($evidenceRoot, [System.StringComparison]::OrdinalIgnoreCase) -and
        (Split-Path -Leaf $validatedRoot) -cmatch '^validate-db22-[a-f0-9]{32}$') `
        -Code "db22_fixture_recursive_cleanup_path_rejected" -FailureClass "source_integrity_rejection"
      if (Test-Path -LiteralPath $validatedRoot -PathType Container) {
        Remove-Item -LiteralPath $validatedRoot -Recurse -Force
      }
    } },
    [pscustomobject]@{ Name = "DB22_FIXTURE_DIRECTORY_ABSENT"; Operation = {
      Assert-Condition -Condition (-not (Test-Path -LiteralPath $fixtureRoot)) `
        -Code "db22_fixture_directory_residue_rejected" -FailureClass "postcondition_rejection"
    } }
  )
  Complete-OrchestrationCleanup -PrimaryError $fixtureError -PrimaryScenario $fixtureScenario -CleanupResult $fixtureCleanup `
    -CleanupFailureCode "db22_fixture_cleanup_rejected"
  Assert-Condition -Condition (-not (Test-Path -LiteralPath $fixtureRoot)) -Code "db22_fixture_directory_residue_rejected"
}

function Invoke-Db23ExpectedPsqlFailure {
  param(
    [Parameter(Mandatory = $true)][scriptblock]$Operation,
    [Parameter(Mandatory = $true)][string]$ExpectedCode
  )
  $captured = $null
  try { [void](& $Operation) }
  catch { $captured = $_ }
  Assert-Condition -Condition ($null -ne $captured -and $captured.Exception.Message -ceq $ExpectedCode) `
    -Code ("db23_" + $ExpectedCode + "_fixture_rejected") -FailureClass "source_integrity_rejection"
  return $captured
}

function Assert-Db23PsqlHandoffFixtures {
  $originalScenario = $script:CurrentScenario
  $fixtureRoot = [System.IO.Path]::GetFullPath((Join-Path $script:EvidenceRoot ("validate-db23-" + [guid]::NewGuid().ToString("N"))))
  $evidenceRoot = [System.IO.Path]::GetFullPath($script:EvidenceRoot).TrimEnd('\') + '\'
  Assert-Condition -Condition ($fixtureRoot.StartsWith($evidenceRoot, [System.StringComparison]::OrdinalIgnoreCase) -and
    (Split-Path -Leaf $fixtureRoot) -cmatch '^validate-db23-[a-f0-9]{32}$') `
    -Code "db23_fixture_root_rejected" -FailureClass "source_integrity_rejection"
  if (-not (Test-Path -LiteralPath $script:EvidenceRoot -PathType Container)) {
    [void](New-Item -ItemType Directory -Path $script:EvidenceRoot -Force)
  }
  [void](New-Item -ItemType Directory -Path $fixtureRoot)
  $fixtureError = $null
  $fixtureScenario = $null
  $script:Db23FixtureStartAttemptCount = 0
  $script:Db23LastCreatedSqlFile = $null
  $script:Db23LastHandoffState = $null
  try {
    $dummyConnection = [pscustomobject]@{}
    $dummyPsqlPath = "unreachable-psql.exe"
    $sql = "select 1;"

    $directArtifact = New-SqlFile -RunDirectory $fixtureRoot -Label "db23_direct_overflow" -Sql $sql -InitialOwner controller
    $directPath = $directArtifact.Path
    $directState = $directArtifact.OwnershipState
    $directStartCount = $script:Db23FixtureStartAttemptCount
    $directError = Invoke-Db23ExpectedPsqlFailure -ExpectedCode "psql_process_timeout_overflow_rejected" -Operation {
      Invoke-PsqlFile -Connection $dummyConnection -PsqlPath $dummyPsqlPath -SqlFile $directPath `
        -ApplicationName "sitaa_sem01_db23_direct_overflow" -RunDirectory $fixtureRoot `
        -StatementTimeoutMilliseconds 570001 -ProcessTimeoutMilliseconds 0 -DeleteSqlFileOnCompletion $true `
        -DisposableSqlOwnershipState $directState
    }
    Assert-Condition -Condition ($script:Db23FixtureStartAttemptCount -eq $directStartCount -and
      -not (Test-Path -LiteralPath $directPath) -and $directState.CleanupInvocationCount -eq 1 -and
      $directState.RemovalAttemptCount -eq 1 -and $directState.AbsenceObserved -and
      -not $directState.CallerOwns -and -not $directState.ControllerOwns -and -not $directState.WorkerOwns -and
      [object]::ReferenceEquals($directState.PrimaryErrorRecord.Exception, $directError.Exception)) `
      -Code "db23_direct_timeout_cleanup_fixture_rejected" -FailureClass "source_integrity_rejection"

    $negativeArtifact = New-SqlFile -RunDirectory $fixtureRoot -Label "db23_negative_timeout" -Sql $sql -InitialOwner controller
    $negativePath = $negativeArtifact.Path
    $negativeState = $negativeArtifact.OwnershipState
    $negativeStartCount = $script:Db23FixtureStartAttemptCount
    [void](Invoke-Db23ExpectedPsqlFailure -ExpectedCode "psql_statement_timeout_negative_rejected" -Operation {
      Invoke-PsqlFile -Connection $dummyConnection -PsqlPath $dummyPsqlPath -SqlFile $negativePath `
        -ApplicationName "sitaa_sem01_db23_negative_timeout" -RunDirectory $fixtureRoot `
        -StatementTimeoutMilliseconds -1 -ProcessTimeoutMilliseconds 0 -DeleteSqlFileOnCompletion $true `
        -DisposableSqlOwnershipState $negativeState
    })
    Assert-Condition -Condition ($script:Db23FixtureStartAttemptCount -eq $negativeStartCount -and
      -not (Test-Path -LiteralPath $negativePath) -and $negativeState.AbsenceObserved -and
      -not $negativeState.ControllerOwns -and -not $negativeState.WorkerOwns) `
      -Code "db23_negative_timeout_cleanup_fixture_rejected" -FailureClass "source_integrity_rejection"

    $script:Db23LastCreatedSqlFile = $null
    $script:Db23LastHandoffState = $null
    $handoffStartCount = $script:Db23FixtureStartAttemptCount
    $handoffError = Invoke-Db23ExpectedPsqlFailure -ExpectedCode "psql_process_timeout_overflow_rejected" -Operation {
      Invoke-PsqlSql -Connection $dummyConnection -PsqlPath $dummyPsqlPath -Sql $sql `
        -ApplicationName "sitaa_sem01_db23_handoff" -RunDirectory $fixtureRoot `
        -StatementTimeoutMilliseconds 570001 -ProcessTimeoutMilliseconds 0
    }
    $handoffState = $script:Db23LastHandoffState
    Assert-Condition -Condition ($script:Db23FixtureStartAttemptCount -eq $handoffStartCount -and
      $null -ne $handoffState -and -not [string]::IsNullOrWhiteSpace([string]$script:Db23LastCreatedSqlFile) -and
      -not (Test-Path -LiteralPath $script:Db23LastCreatedSqlFile) -and
      $handoffState.CleanupInvocationCount -eq 1 -and $handoffState.AbsenceObserved -and
      [string]$handoffState.OwnerState -ceq "completed" -and
      -not $handoffState.CallerOwns -and -not $handoffState.ControllerOwns -and -not $handoffState.WorkerOwns -and
      [object]::ReferenceEquals($handoffState.PrimaryErrorRecord.Exception, $handoffError.Exception)) `
      -Code "db23_outer_handoff_cleanup_fixture_rejected" -FailureClass "source_integrity_rejection"

    $protectedHash = Get-Sha256 -Path $script:MigrationPath
    $protectedState = New-PsqlDisposableOwnershipState -SqlFile $script:MigrationPath -RunDirectory $fixtureRoot
    $protectedStartCount = $script:Db23FixtureStartAttemptCount
    [void](Invoke-Db23ExpectedPsqlFailure -ExpectedCode "psql_process_timeout_overflow_rejected" -Operation {
      Invoke-PsqlFile -Connection $dummyConnection -PsqlPath $dummyPsqlPath -SqlFile $script:MigrationPath `
        -ApplicationName "sitaa_sem01_db23_protected" -RunDirectory $fixtureRoot `
        -StatementTimeoutMilliseconds 570001 -ProcessTimeoutMilliseconds 0 -DeleteSqlFileOnCompletion $false `
        -DisposableSqlOwnershipState $protectedState
    })
    Assert-Condition -Condition ($script:Db23FixtureStartAttemptCount -eq $protectedStartCount -and
      (Test-Path -LiteralPath $script:MigrationPath -PathType Leaf) -and (Get-Sha256 -Path $script:MigrationPath) -ceq $protectedHash -and
      -not $protectedState.CallerOwns -and -not $protectedState.ControllerOwns -and -not $protectedState.WorkerOwns -and
      -not $protectedState.CleanupAttempted -and $protectedState.RemovalAttemptCount -eq 0) `
      -Code "db23_protected_sql_preservation_fixture_rejected" -FailureClass "source_integrity_rejection"

    $missingPath = Join-Path $fixtureRoot ("worker_db23_missing_" + [guid]::NewGuid().ToString("N") + ".sql")
    Assert-DisposableWorkerSqlPath -SqlFile $missingPath -RunDirectory $fixtureRoot
    $missingState = New-PsqlDisposableOwnershipState -RunDirectory $fixtureRoot
    $missingIdentity = [pscustomobject]@{
      CanonicalPath = [System.IO.Path]::GetFullPath($missingPath)
      CanonicalRunDirectory = [System.IO.Path]::GetFullPath($fixtureRoot).TrimEnd('\', '/')
      CanonicalFileName = Split-Path -Leaf $missingPath
      ExpectedSha256 = ("0" * 64)
      ExpectedByteLength = [long]1
    }
    Set-PsqlDisposableFrozenIdentity -State $missingState -Identity $missingIdentity
    Set-PsqlDisposableControllerOwnership -State $missingState -SqlFile $missingPath -RunDirectory $fixtureRoot
    [void](Invoke-Db23ExpectedPsqlFailure -ExpectedCode "worker_sql_file_missing" -Operation {
      Invoke-PsqlFile -Connection $dummyConnection -PsqlPath $dummyPsqlPath -SqlFile $missingPath `
        -ApplicationName "sitaa_sem01_db23_missing" -RunDirectory $fixtureRoot `
        -StatementTimeoutMilliseconds 90000 -ProcessTimeoutMilliseconds 0 -DeleteSqlFileOnCompletion $true `
        -DisposableSqlOwnershipState $missingState
    })
    Assert-Condition -Condition ($missingState.CleanupInvocationCount -eq 1 -and $missingState.AbsenceObserved -and
      -not (Test-Path -LiteralPath $missingPath) -and $script:Db23FixtureStartAttemptCount -eq $protectedStartCount) `
      -Code "db23_missing_disposable_idempotent_cleanup_fixture_rejected" -FailureClass "source_integrity_rejection"

    $outsidePath = $script:MigrationPath
    $outsideHash = Get-Sha256 -Path $outsidePath
    $outsideState = New-PsqlDisposableOwnershipState -SqlFile $outsidePath -RunDirectory $fixtureRoot
    $previousWarningPreference = $WarningPreference
    $WarningPreference = "SilentlyContinue"
    try {
      $guardError = Invoke-Db23ExpectedPsqlFailure -ExpectedCode "worker_sql_delete_repository_rejected" -Operation {
        Invoke-PsqlFile -Connection $dummyConnection -PsqlPath $dummyPsqlPath -SqlFile $outsidePath `
          -ApplicationName "sitaa_sem01_db23_guard" -RunDirectory $fixtureRoot `
          -StatementTimeoutMilliseconds 90000 -ProcessTimeoutMilliseconds 0 -DeleteSqlFileOnCompletion $true `
          -DisposableSqlOwnershipState $outsideState
      }
    }
    catch {
      $WarningPreference = $previousWarningPreference
      throw $_
    }
    $WarningPreference = $previousWarningPreference
    Assert-Condition -Condition ([object]::ReferenceEquals($outsideState.PrimaryErrorRecord.Exception, $guardError.Exception) -and
      (Get-Sha256 -Path $outsidePath) -ceq $outsideHash -and $outsideState.RemovalAttemptCount -eq 0 -and
      @($outsideState.SecondaryCleanupErrors).Count -eq 0 -and -not $outsideState.CleanupAttempted -and
      $script:Db23FixtureStartAttemptCount -eq $protectedStartCount) `
      -Code "db23_guard_failure_primary_and_no_remove_fixture_rejected" -FailureClass "source_integrity_rejection"

    $secondaryArtifact = New-SqlFile -RunDirectory $fixtureRoot -Label "db23_secondary_cleanup" -Sql $sql -InitialOwner controller
    $secondaryPath = $secondaryArtifact.Path
    $secondaryState = $secondaryArtifact.OwnershipState
    $script:PsqlHandoffFixtureFault = "removal_failure"
    $previousWarningPreference = $WarningPreference
    $WarningPreference = "SilentlyContinue"
    try {
      $secondaryPrimary = Invoke-Db23ExpectedPsqlFailure -ExpectedCode "psql_process_timeout_overflow_rejected" -Operation {
        Invoke-PsqlFile -Connection $dummyConnection -PsqlPath $dummyPsqlPath -SqlFile $secondaryPath `
          -ApplicationName "sitaa_sem01_db23_secondary" -RunDirectory $fixtureRoot `
          -StatementTimeoutMilliseconds 570001 -ProcessTimeoutMilliseconds 0 -DeleteSqlFileOnCompletion $true `
          -DisposableSqlOwnershipState $secondaryState
      }
    }
    catch {
      $WarningPreference = $previousWarningPreference
      $script:PsqlHandoffFixtureFault = $null
      throw $_
    }
    $WarningPreference = $previousWarningPreference
    $script:PsqlHandoffFixtureFault = $null
    Assert-Condition -Condition ([object]::ReferenceEquals($secondaryState.PrimaryErrorRecord.Exception, $secondaryPrimary.Exception) -and
      (Test-Path -LiteralPath $secondaryPath -PathType Leaf) -and -not $secondaryState.AbsenceObserved -and
      @($secondaryState.SecondaryCleanupErrors).Count -ge 1) `
      -Code "db23_secondary_cleanup_primary_preservation_fixture_rejected" -FailureClass "source_integrity_rejection"
    $secondaryFinalCleanup = Invoke-PsqlDisposableControllerCleanup -State $secondaryState
    Complete-OrchestrationCleanup -PrimaryError $null -PrimaryScenario $null -CleanupResult $secondaryFinalCleanup `
      -CleanupFailureCode "db23_secondary_fixture_final_cleanup_rejected"

    $modelArtifact = New-SqlFile -RunDirectory $fixtureRoot -Label "db23_success_model" -Sql $sql -InitialOwner caller
    $modelPath = $modelArtifact.Path
    $modelState = $modelArtifact.OwnershipState
    Assert-Condition -Condition ($modelState.CallerOwns -and -not $modelState.ControllerOwns -and -not $modelState.WorkerOwns) `
      -Code "db23_success_model_caller_owner_fixture_rejected"
    Set-PsqlDisposableControllerOwnership -State $modelState -SqlFile $modelPath -RunDirectory $fixtureRoot
    Assert-Condition -Condition (-not $modelState.CallerOwns -and $modelState.ControllerOwns -and -not $modelState.WorkerOwns) `
      -Code "db23_success_model_controller_owner_fixture_rejected"
    $modelProcess = [pscustomobject]@{ Id = 23001; HasExited = $false }
    Set-PsqlDisposableStarterOwnership -State $modelState -Process $modelProcess
    $modelState.ProcessId = 23001
    $modelState.ProcessIdObserved = $true
    $modelState.StartInfo = New-Object System.Diagnostics.ProcessStartInfo
    $modelState.StartInfoMaterialClearAttempted = $true
    $modelState.StartInfoMaterialCleared = $true
    $modelState.LocalPidAddAttempted = $true
    $modelState.LocalPidRecorded = $true
    $modelWorker = [pscustomobject]@{
      Process = $modelProcess; SqlFile = $modelPath; RunDirectory = $fixtureRoot
      DisposableSqlOwnershipState = $modelState; ExecutionContext = $null
    }
    Set-PsqlDisposableWorkerOwnership -State $modelState -Worker $modelWorker
    Assert-Condition -Condition (-not $modelState.CallerOwns -and -not $modelState.ControllerOwns -and
      $modelState.WorkerOwns -and -not $modelState.CleanupAttempted -and $modelState.WorkerTransferCount -eq 1) `
      -Code "db23_success_model_worker_owner_fixture_rejected"
    Assert-DisposableWorkerSqlPath -SqlFile $modelPath -RunDirectory $fixtureRoot
    Remove-Item -LiteralPath $modelPath -Force
    $modelState.ProcessTerminationObserved = $true
    Complete-PsqlDisposableWorkerOwnership -State $modelState
    Assert-Condition -Condition (-not $modelState.CallerOwns -and -not $modelState.ControllerOwns -and
      -not $modelState.WorkerOwns -and $modelState.AbsenceObserved -and $modelState.CollectionCount -eq 1 -and
      $modelState.CleanupInvocationCount -eq 0) -Code "db23_success_model_collection_fixture_rejected"

    Assert-Condition -Condition ($script:Db23FixtureStartAttemptCount -eq 0 -and
      (Get-TransientWorkerSqlFileCount -RunDirectory $fixtureRoot) -eq 0) `
      -Code "db23_fixture_worker_or_sql_residue_rejected" -FailureClass "postcondition_rejection"
  }
  catch {
    $fixtureError = $_
    $fixtureScenario = [string]$script:CurrentScenario
  }
  $script:PsqlHandoffFixtureFault = $null
  $script:Db23LastCreatedSqlFile = $null
  $script:Db23LastHandoffState = $null
  $script:CurrentScenario = $originalScenario
  $fixtureCleanup = Invoke-OrchestrationCleanup -CleanupOperations @(
    [pscustomobject]@{ Name = "DB23_FIXTURE_FILES_REMOVE"; Operation = {
      if (Test-Path -LiteralPath $fixtureRoot -PathType Container) {
        foreach ($item in @(Get-ChildItem -LiteralPath $fixtureRoot -File -Force)) {
          Assert-DisposableWorkerSqlPath -SqlFile $item.FullName -RunDirectory $fixtureRoot
          Remove-Item -LiteralPath $item.FullName -Force
        }
      }
    } },
    [pscustomobject]@{ Name = "DB23_FIXTURE_DIRECTORY_REMOVE"; Operation = {
      $validatedRoot = [System.IO.Path]::GetFullPath($fixtureRoot)
      Assert-Condition -Condition ($validatedRoot.StartsWith($evidenceRoot, [System.StringComparison]::OrdinalIgnoreCase) -and
        (Split-Path -Leaf $validatedRoot) -cmatch '^validate-db23-[a-f0-9]{32}$') `
        -Code "db23_fixture_recursive_cleanup_path_rejected" -FailureClass "source_integrity_rejection"
      if (Test-Path -LiteralPath $validatedRoot -PathType Container) {
        Remove-Item -LiteralPath $validatedRoot -Recurse -Force
      }
    } },
    [pscustomobject]@{ Name = "DB23_FIXTURE_DIRECTORY_ABSENT"; Operation = {
      Assert-Condition -Condition (-not (Test-Path -LiteralPath $fixtureRoot)) `
        -Code "db23_fixture_directory_residue_rejected" -FailureClass "postcondition_rejection"
    } }
  )
  Complete-OrchestrationCleanup -PrimaryError $fixtureError -PrimaryScenario $fixtureScenario -CleanupResult $fixtureCleanup `
    -CleanupFailureCode "db23_fixture_cleanup_rejected"
  Assert-Condition -Condition (-not (Test-Path -LiteralPath $fixtureRoot)) -Code "db23_fixture_directory_residue_rejected"
}

function New-Db24SyntheticProcess {
  param(
    [Parameter(Mandatory = $true)][int]$ProcessId,
    [Parameter(Mandatory = $true)][bool]$TerminationSucceeds
  )
  $model = [pscustomobject]@{
    HasExited = $false
    TerminationSucceeds = $TerminationSucceeds
    InputCloseCount = 0
    KillCount = 0
    WaitCount = 0
  }
  $input = [pscustomobject]@{ Model = $model }
  $input | Add-Member -MemberType ScriptMethod -Name Close -Value { $this.Model.InputCloseCount++ }
  $process = [pscustomobject]@{ Id = $ProcessId; Model = $model; StandardInput = $input }
  $process | Add-Member -MemberType ScriptProperty -Name HasExited -Value { [bool]$this.Model.HasExited }
  $process | Add-Member -MemberType ScriptMethod -Name Kill -Value {
    $this.Model.KillCount++
    if (-not $this.Model.TerminationSucceeds) { throw "db24_synthetic_termination_failure" }
    $this.Model.HasExited = $true
  }
  $process | Add-Member -MemberType ScriptMethod -Name WaitForExit -Value {
    param([int]$TimeoutMilliseconds)
    $this.Model.WaitCount++
    return [bool]$this.Model.HasExited
  }
  return $process
}

function New-Db24OwnedFixtureState {
  param([Parameter(Mandatory = $true)][object]$Artifact)
  $state = $Artifact.OwnershipState
  Assert-Condition -Condition ([string]$state.OwnerState -ceq "controller" -and $state.IdentityFrozen) `
    -Code "db24_owned_artifact_rejected" -FailureClass "source_integrity_rejection"
  $state | Add-Member -NotePropertyName FixturePidOperationsOnly -NotePropertyValue $true
  $state | Add-Member -NotePropertyName FixtureLocalPidRemovalCount -NotePropertyValue 0
  $state | Add-Member -NotePropertyName FixtureExecutePidRemovalCount -NotePropertyValue 0
  return $state
}

function Invoke-Db24ExpectedFailure {
  param(
    [Parameter(Mandatory = $true)][scriptblock]$Operation,
    [Parameter(Mandatory = $true)][string]$ExpectedCode
  )
  $captured = $null
  try { [void](& $Operation) }
  catch { $captured = $_ }
  Assert-Condition -Condition ($null -ne $captured -and $captured.Exception.Message -ceq $ExpectedCode) `
    -Code ("db24_" + $ExpectedCode + "_fixture_rejected") -FailureClass "source_integrity_rejection"
  return $captured
}

function Assert-Db24TransientSqlIdentityAndStarterEscrowFixtures {
  $originalScenario = $script:CurrentScenario
  $fixtureRoot = [System.IO.Path]::GetFullPath((Join-Path $script:EvidenceRoot ("validate-db24-" + [guid]::NewGuid().ToString("N"))))
  $evidenceRoot = [System.IO.Path]::GetFullPath($script:EvidenceRoot).TrimEnd('\', '/') + [System.IO.Path]::DirectorySeparatorChar
  Assert-Condition -Condition ($fixtureRoot.StartsWith($evidenceRoot, [System.StringComparison]::OrdinalIgnoreCase) -and
    (Split-Path -Leaf $fixtureRoot) -cmatch '^validate-db24-[a-f0-9]{32}$') `
    -Code "db24_fixture_root_rejected" -FailureClass "source_integrity_rejection"
  if (-not (Test-Path -LiteralPath $script:EvidenceRoot -PathType Container)) {
    [void](New-Item -ItemType Directory -Path $script:EvidenceRoot -Force)
  }
  [void](New-Item -ItemType Directory -Path $fixtureRoot)
  $fixtureError = $null
  $fixtureScenario = $null
  $script:Db24FixtureStartAttemptCount = 0
  $script:Db24LastCreatedSqlFile = $null
  $script:Db24LastHandoffState = $null
  $encoding = New-Object System.Text.UTF8Encoding($false)
  try {
    $sql = "select 1;"
    $canonicalArtifact = New-SqlFile -RunDirectory $fixtureRoot -Label "db24_canonical" -Sql $sql -InitialOwner caller
    $canonicalPath = $canonicalArtifact.Path
    $canonicalIdentity = $canonicalArtifact
    $canonicalState = $canonicalArtifact.OwnershipState
    Assert-Condition -Condition ([string]$canonicalState.OwnerState -ceq "caller" -and
      [string]$canonicalState.ExpectedSha256 -ceq (Get-Sha256 -Path $canonicalPath) -and
      [string]$canonicalIdentity.CanonicalFileName -cmatch '^worker_[a-z0-9_]+_[0-9a-f]{32}\.sql$' -and
      [string]::Equals((Split-Path -Parent $canonicalIdentity.CanonicalPath), $canonicalIdentity.CanonicalRunDirectory, [System.StringComparison]::OrdinalIgnoreCase)) `
      -Code "db24_canonical_worker_fixture_rejected" -FailureClass "source_integrity_rejection"

    $nonWorkerNames = @(
      "manifest.local.json", "worker-pids.local.json", "final-postcheck.local.txt", "failure-postcheck.local.txt",
      "multisession-evidence.local.txt", "multisession-failure.local.txt", "multisession-evidence.local.txt.publishing",
      "raw_fixture.stdout.local.txt"
    )
    foreach ($name in $nonWorkerNames) {
      $path = Join-Path $fixtureRoot $name
      [System.IO.File]::WriteAllText($path, ("db24 non-worker " + $name + "`n"), $encoding)
      $hash = Get-Sha256 -Path $path
      [void](Invoke-Db24ExpectedFailure -ExpectedCode "worker_sql_delete_filename_rejected" -Operation {
        Assert-DisposableWorkerSqlPath -SqlFile $path -RunDirectory $fixtureRoot
      })
      $manualState = New-PsqlDisposableOwnershipState -SqlFile $path -RunDirectory $fixtureRoot
      $manualState.FrozenCanonicalFileName = $name
      $manualState.FrozenExpectedSha256 = $hash
      $manualState.FrozenExpectedByteLength = [long](Get-Item -LiteralPath $path -Force).Length
      $manualState.IdentityFrozen = $true
      $manualState.OwnerState = "controller"
      $cleanup = Invoke-PsqlDisposableControllerCleanup -State $manualState
      Assert-Condition -Condition (-not $cleanup.Succeeded -and (Test-Path -LiteralPath $path -PathType Leaf) -and
        (Get-Sha256 -Path $path) -ceq $hash -and [string]$manualState.OwnerState -ceq "controller") `
        -Code "db24_nonworker_cleanup_fixture_rejected" -FailureClass "source_integrity_rejection"
    }

    $hex32 = [guid]::NewGuid().ToString("N")
    $malformedRelativePaths = @(
      "worker_fixture.sql", "worker_fixture_ABCDEF.sql", ("WORKER_fixture_" + $hex32 + ".sql"),
      ("worker_fixture_" + $hex32.Substring(0, 31) + ".sql"), ("worker_fixture_" + $hex32 + "a.sql"),
      ("worker_fixture_" + $hex32 + ".sql.extra")
    )
    foreach ($relative in $malformedRelativePaths) {
      $path = Join-Path $fixtureRoot $relative
      [System.IO.File]::WriteAllText($path, "db24 malformed`n", $encoding)
      $hash = Get-Sha256 -Path $path
      [void](Invoke-Db24ExpectedFailure -ExpectedCode "worker_sql_delete_filename_rejected" -Operation {
        Assert-DisposableWorkerSqlPath -SqlFile $path -RunDirectory $fixtureRoot
      })
      Assert-Condition -Condition ((Get-Sha256 -Path $path) -ceq $hash) -Code "db24_malformed_worker_preservation_rejected"
    }
    $nestedRoot = Join-Path $fixtureRoot "nested"
    [void](New-Item -ItemType Directory -Path $nestedRoot)
    $nestedPath = Join-Path $nestedRoot ("worker_fixture_" + $hex32 + ".sql")
    [System.IO.File]::WriteAllText($nestedPath, "db24 nested`n", $encoding)
    $nestedHash = Get-Sha256 -Path $nestedPath
    [void](Invoke-Db24ExpectedFailure -ExpectedCode "worker_sql_delete_outside_run_root" -Operation {
      Assert-DisposableWorkerSqlPath -SqlFile $nestedPath -RunDirectory $fixtureRoot
    })
    Assert-Condition -Condition ((Get-Sha256 -Path $nestedPath) -ceq $nestedHash) -Code "db24_nested_worker_preservation_rejected"

    $identityArtifactA = New-SqlFile -RunDirectory $fixtureRoot -Label "db24_identity_a" -Sql $sql -InitialOwner caller
    $identityArtifactB = New-SqlFile -RunDirectory $fixtureRoot -Label "db24_identity_b" -Sql $sql -InitialOwner controller
    $identityA = $identityArtifactA.Path
    $identityB = $identityArtifactB.Path
    $handoffState = $identityArtifactA.OwnershipState
    $beforeHandoff = @($handoffState.CanonicalPath, $handoffState.CanonicalRunDirectory, $handoffState.CanonicalFileName,
      $handoffState.ExpectedSha256, $handoffState.OwnerState, $handoffState.CleanupInvocationCount) -join "|"
    [void](Invoke-Db24ExpectedFailure -ExpectedCode "psql_disposable_handoff_identity_rejected" -Operation {
      Set-PsqlDisposableControllerOwnership -State $handoffState -SqlFile $identityB -RunDirectory $fixtureRoot
    })
    $afterHandoff = @($handoffState.CanonicalPath, $handoffState.CanonicalRunDirectory, $handoffState.CanonicalFileName,
      $handoffState.ExpectedSha256, $handoffState.OwnerState, $handoffState.CleanupInvocationCount) -join "|"
    Assert-Condition -Condition ($beforeHandoff -ceq $afterHandoff -and (Test-Path -LiteralPath $identityA) -and
      (Test-Path -LiteralPath $identityB) -and [string]$handoffState.OwnerState -ceq "caller") `
      -Code "db24_failure_atomic_handoff_fixture_rejected"
    $cleanupA = Invoke-PsqlDisposableControllerCleanup -State $handoffState
    $stateB = New-Db24OwnedFixtureState -Artifact $identityArtifactB
    $cleanupB = Invoke-PsqlDisposableControllerCleanup -State $stateB
    Assert-Condition -Condition ($cleanupA.Succeeded -and $cleanupB.Succeeded) -Code "db24_identity_fixture_cleanup_rejected"

    $dummyConnection = [pscustomobject]@{}
    $dummyPsqlPath = "unreachable-psql.exe"
    $script:Db24LastCreatedSqlFile = $null
    $script:Db24LastHandoffState = $null
    $overflowError = Invoke-Db24ExpectedFailure -ExpectedCode "psql_process_timeout_overflow_rejected" -Operation {
      Invoke-PsqlSql -Connection $dummyConnection -PsqlPath $dummyPsqlPath -Sql $sql `
        -ApplicationName "sitaa_sem01_db24_handoff" -RunDirectory $fixtureRoot `
        -StatementTimeoutMilliseconds 570001 -ProcessTimeoutMilliseconds 0
    }
    $completedState = $script:Db24LastHandoffState
    $completedPath = [string]$script:Db24LastCreatedSqlFile
    Assert-Condition -Condition ($null -ne $completedState -and [string]$completedState.OwnerState -ceq "completed" -and
      $completedState.CleanupInvocationCount -eq 1 -and $completedState.RemovalAttemptCount -eq 1 -and
      -not (Test-Path -LiteralPath $completedPath) -and
      [object]::ReferenceEquals($completedState.PrimaryErrorRecord.Exception, $overflowError.Exception)) `
      -Code "db24_single_inner_cleanup_fixture_rejected"
    [System.IO.File]::WriteAllText($completedPath, "db24 replacement after completed`n", $encoding)
    $completedReplacementHash = Get-Sha256 -Path $completedPath
    [void](Invoke-Db24ExpectedFailure -ExpectedCode "psql_handoff_completed_path_reappeared" -Operation {
      Invoke-PsqlSqlOuterHandoffCleanup -State $completedState
    })
    Assert-Condition -Condition ((Get-Sha256 -Path $completedPath) -ceq $completedReplacementHash -and
      $completedState.CleanupInvocationCount -eq 1) -Code "db24_completed_owner_second_delete_fixture_rejected"

    $replacementArtifact = New-SqlFile -RunDirectory $fixtureRoot -Label "db24_hash_replacement" -Sql $sql -InitialOwner controller
    $replacementPath = $replacementArtifact.Path
    $replacementState = New-Db24OwnedFixtureState -Artifact $replacementArtifact
    $replacementPrimary = Invoke-Db24ExpectedFailure -ExpectedCode "psql_process_timeout_overflow_rejected" -Operation {
      Resolve-PsqlProcessTimeoutMilliseconds -StatementTimeoutMilliseconds 570001 -ProcessTimeoutMilliseconds 0
    }
    $replacementState.PrimaryErrorRecord = $replacementPrimary
    [System.IO.File]::WriteAllText($replacementPath, "db24 different content`n", $encoding)
    [void](Invoke-Db24ExpectedFailure -ExpectedCode "psql_disposable_identity_hash_mismatch" -Operation {
      Assert-PsqlDisposableFrozenIdentity -State $replacementState
    })
    $replacementHash = Get-Sha256 -Path $replacementPath
    $replacementCleanup = Invoke-PsqlDisposableControllerCleanup -State $replacementState
    Assert-Condition -Condition (-not $replacementCleanup.Succeeded -and (Test-Path -LiteralPath $replacementPath) -and
      (Get-Sha256 -Path $replacementPath) -ceq $replacementHash -and
      [object]::ReferenceEquals($replacementState.PrimaryErrorRecord.Exception, $replacementPrimary.Exception)) `
      -Code "db24_replacement_identity_fixture_rejected"

    $modelArtifact = New-SqlFile -RunDirectory $fixtureRoot -Label "db24_owner_model" -Sql $sql -InitialOwner controller
    $modelPath = $modelArtifact.Path
    $modelState = New-Db24OwnedFixtureState -Artifact $modelArtifact
    $modelProcess = New-Db24SyntheticProcess -ProcessId 24001 -TerminationSucceeds $true
    Set-PsqlDisposableStarterOwnership -State $modelState -Process $modelProcess
    $modelState.ProcessId = 24001
    $modelState.ProcessIdObserved = $true
    $modelState.StartInfo = New-Object System.Diagnostics.ProcessStartInfo
    $modelState.StartInfoMaterialClearAttempted = $true
    $modelState.StartInfoMaterialCleared = $true
    $modelState.LocalPidAddAttempted = $true
    $modelState.LocalPidRecorded = $true
    Assert-Condition -Condition ([string]$modelState.OwnerState -ceq "starter" -and -not $modelState.ControllerOwns) `
      -Code "db24_starter_owner_fixture_rejected"
    $modelWorker = [pscustomobject]@{ Process = $modelProcess; SqlFile = $modelPath; RunDirectory = $fixtureRoot; DeleteSqlFileOnCompletion = $true; DisposableSqlOwnershipState = $modelState; ExecutionContext = $null }
    Set-PsqlDisposableWorkerOwnership -State $modelState -Worker $modelWorker
    Assert-Condition -Condition ([string]$modelState.OwnerState -ceq "worker" -and $modelState.WorkerOwns) `
      -Code "db24_worker_owner_fixture_rejected"
    $modelProcess.Model.HasExited = $true
    Remove-DisposableWorkerSqlFile -Worker $modelWorker
    Complete-PsqlDisposableWorkerOwnership -State $modelState
    Assert-Condition -Condition ([string]$modelState.OwnerState -ceq "completed" -and $modelState.AbsenceObserved) `
      -Code "db24_owner_model_completion_fixture_rejected"

    $successfulFailureArtifact = New-SqlFile -RunDirectory $fixtureRoot -Label "db24_post_start_success" -Sql $sql -InitialOwner controller
    $successfulFailurePath = $successfulFailureArtifact.Path
    $successfulFailureState = New-Db24OwnedFixtureState -Artifact $successfulFailureArtifact
    $successfulProcess = New-Db24SyntheticProcess -ProcessId 24002 -TerminationSucceeds $true
    Set-PsqlDisposableStarterOwnership -State $successfulFailureState -Process $successfulProcess
    $successfulFailureState.ProcessId = 24002
    $successfulFailureState.ProcessIdObserved = $true
    $successfulFailureState.LocalPidAddAttempted = $true
    $successfulFailureState.ExecutePidAddAttempted = $true
    $startPrimary = Invoke-Db24ExpectedFailure -ExpectedCode "db24_synthetic_start_failure" -Operation {
      Throw-StableFailure -Code "db24_synthetic_start_failure" -FailureClass "worker_crash"
    }
    $successfulFailureState.PrimaryErrorRecord = $startPrimary
    $successfulFailureCleanup = Invoke-PsqlWorkerStartFailureCleanup -State $successfulFailureState `
      -ApplicationName "sitaa_sem01_db24_success" -RunDirectory $fixtureRoot -WorkerExecutionContext $null -DeleteSqlFileOnCompletion $true
    Assert-Condition -Condition ($successfulFailureCleanup.Succeeded -and [string]$successfulFailureState.OwnerState -ceq "completed" -and
      $successfulFailureState.ProcessTerminationObserved -and $successfulFailureState.FixtureLocalPidRemovalCount -eq 1 -and
      $successfulFailureState.FixtureExecutePidRemovalCount -eq 1 -and -not (Test-Path -LiteralPath $successfulFailurePath) -and
      [object]::ReferenceEquals($successfulFailureState.PrimaryErrorRecord.Exception, $startPrimary.Exception)) `
      -Code "db24_post_start_successful_cleanup_fixture_rejected"

    $failedTerminationArtifact = New-SqlFile -RunDirectory $fixtureRoot -Label "db24_post_start_failure" -Sql $sql -InitialOwner controller
    $failedTerminationPath = $failedTerminationArtifact.Path
    $failedTerminationState = New-Db24OwnedFixtureState -Artifact $failedTerminationArtifact
    $failedProcess = New-Db24SyntheticProcess -ProcessId 24003 -TerminationSucceeds $false
    Set-PsqlDisposableStarterOwnership -State $failedTerminationState -Process $failedProcess
    $failedTerminationState.ProcessId = 24003
    $failedTerminationState.ProcessIdObserved = $true
    $failedTerminationState.LocalPidAddAttempted = $true
    $failedTerminationState.ExecutePidAddAttempted = $true
    $terminationPrimary = Invoke-Db24ExpectedFailure -ExpectedCode "db24_synthetic_start_failure" -Operation {
      Throw-StableFailure -Code "db24_synthetic_start_failure" -FailureClass "worker_crash"
    }
    $failedTerminationState.PrimaryErrorRecord = $terminationPrimary
    $failedTerminationCleanup = Invoke-PsqlWorkerStartFailureCleanup -State $failedTerminationState `
      -ApplicationName "sitaa_sem01_db24_failure" -RunDirectory $fixtureRoot -WorkerExecutionContext $null -DeleteSqlFileOnCompletion $true
    Assert-Condition -Condition (-not $failedTerminationCleanup.Succeeded -and [string]$failedTerminationState.OwnerState -ceq "starter" -and
      -not $failedTerminationState.ProcessTerminationObserved -and (Test-Path -LiteralPath $failedTerminationPath) -and
      $failedTerminationState.LocalPidRemovalAttempted -and $failedTerminationState.ExecutePidRemovalAttempted -and
      @($failedTerminationState.SecondaryCleanupErrors).Count -ge 1 -and
      [object]::ReferenceEquals($failedTerminationState.PrimaryErrorRecord.Exception, $terminationPrimary.Exception)) `
      -Code "db24_post_start_failed_termination_fixture_rejected"
    $failedProcess.Model.HasExited = $true
    $failedTerminationState.ProcessTerminationObserved = $true
    $failedFinalCleanup = Invoke-PsqlDisposableStarterCleanup -State $failedTerminationState
    Assert-Condition -Condition ($failedFinalCleanup.Succeeded -and [string]$failedTerminationState.OwnerState -ceq "completed") `
      -Code "db24_post_start_independent_final_cleanup_rejected"

    $pairedStates = @()
    foreach ($role in @("holder", "waiter")) {
      $pairedArtifact = New-SqlFile -RunDirectory $fixtureRoot -Label ("db24_pair_" + $role) -Sql $sql -InitialOwner controller
      $pairedPath = $pairedArtifact.Path
      $pairedState = New-Db24OwnedFixtureState -Artifact $pairedArtifact
      $pairedProcessId = if ($role -ceq "holder") { 24004 } else { 24005 }
      $pairedProcess = New-Db24SyntheticProcess -ProcessId $pairedProcessId `
        -TerminationSucceeds ($role -ceq "waiter")
      Set-PsqlDisposableStarterOwnership -State $pairedState -Process $pairedProcess
      $pairedState.ProcessId = $pairedProcessId
      $pairedState.ProcessIdObserved = $true
      $pairedState.LocalPidAddAttempted = $true
      $pairedState.ExecutePidAddAttempted = $true
      $pairedCleanup = Invoke-PsqlWorkerStartFailureCleanup -State $pairedState -ApplicationName ("sitaa_sem01_db24_" + $role) `
        -RunDirectory $fixtureRoot -WorkerExecutionContext $null -DeleteSqlFileOnCompletion $true
      $pairedStates += [pscustomobject]@{ Role = $role; Path = $pairedPath; State = $pairedState; Process = $pairedProcess; Cleanup = $pairedCleanup }
    }
    $holderPair = @($pairedStates | Where-Object { $_.Role -ceq "holder" })[0]
    $waiterPair = @($pairedStates | Where-Object { $_.Role -ceq "waiter" })[0]
    Assert-Condition -Condition ([string]$holderPair.State.OwnerState -ceq "starter" -and (Test-Path -LiteralPath $holderPair.Path) -and
      [string]$waiterPair.State.OwnerState -ceq "completed" -and -not (Test-Path -LiteralPath $waiterPair.Path) -and
      $holderPair.State.RemovalAttemptCount -eq 0 -and $waiterPair.State.RemovalAttemptCount -eq 1) `
      -Code "db24_paired_partial_start_fixture_rejected"
    $holderPair.Process.Model.HasExited = $true
    $holderPair.State.ProcessTerminationObserved = $true
    $holderPairFinalCleanup = Invoke-PsqlDisposableStarterCleanup -State $holderPair.State
    Assert-Condition -Condition $holderPairFinalCleanup.Succeeded -Code "db24_paired_holder_final_cleanup_rejected"

    $protectedHash = Get-Sha256 -Path $script:MigrationPath
    $protectedState = New-PsqlDisposableOwnershipState -SqlFile $script:MigrationPath -RunDirectory $fixtureRoot
    [void](Invoke-Db24ExpectedFailure -ExpectedCode "psql_process_timeout_overflow_rejected" -Operation {
      Invoke-PsqlFile -Connection $dummyConnection -PsqlPath $dummyPsqlPath -SqlFile $script:MigrationPath `
        -ApplicationName "sitaa_sem01_db24_protected" -RunDirectory $fixtureRoot -StatementTimeoutMilliseconds 570001 `
        -ProcessTimeoutMilliseconds 0 -DeleteSqlFileOnCompletion $false -DisposableSqlOwnershipState $protectedState
    })
    $protectedProcess = New-Db24SyntheticProcess -ProcessId 24006 -TerminationSucceeds $true
    $protectedState.Process = $protectedProcess
    $protectedState.ProcessId = 24006
    $protectedState.ProcessStartObserved = $true
    $protectedCleanup = Invoke-PsqlWorkerStartFailureCleanup -State $protectedState -ApplicationName "sitaa_sem01_db24_protected" `
      -RunDirectory $fixtureRoot -WorkerExecutionContext $null -DeleteSqlFileOnCompletion $false
    Assert-Condition -Condition ($protectedCleanup.Succeeded -and [string]$protectedState.OwnerState -ceq "none" -and
      -not $protectedState.CleanupAttempted -and $protectedState.RemovalAttemptCount -eq 0 -and
      (Get-Sha256 -Path $script:MigrationPath) -ceq $protectedHash) `
      -Code "db24_protected_sql_fixture_rejected"

    Assert-Condition -Condition ($script:Db24FixtureStartAttemptCount -eq 0) -Code "db24_real_process_start_fixture_rejected"
  }
  catch {
    $fixtureError = $_
    $fixtureScenario = [string]$script:CurrentScenario
  }
  $script:Db24LastCreatedSqlFile = $null
  $script:Db24LastHandoffState = $null
  $script:CurrentScenario = $originalScenario
  $fixtureCleanup = Invoke-OrchestrationCleanup -CleanupOperations @(
    [pscustomobject]@{ Name = "DB24_FIXTURE_DIRECTORY_REMOVE"; Operation = {
      $validatedRoot = [System.IO.Path]::GetFullPath($fixtureRoot)
      Assert-Condition -Condition ($validatedRoot.StartsWith($evidenceRoot, [System.StringComparison]::OrdinalIgnoreCase) -and
        (Split-Path -Leaf $validatedRoot) -cmatch '^validate-db24-[a-f0-9]{32}$') `
        -Code "db24_fixture_recursive_cleanup_path_rejected" -FailureClass "source_integrity_rejection"
      if (Test-Path -LiteralPath $validatedRoot -PathType Container) {
        Remove-Item -LiteralPath $validatedRoot -Recurse -Force
      }
    } },
    [pscustomobject]@{ Name = "DB24_FIXTURE_DIRECTORY_ABSENT"; Operation = {
      Assert-Condition -Condition (-not (Test-Path -LiteralPath $fixtureRoot)) `
        -Code "db24_fixture_directory_residue_rejected" -FailureClass "postcondition_rejection"
    } }
  )
  Complete-OrchestrationCleanup -PrimaryError $fixtureError -PrimaryScenario $fixtureScenario -CleanupResult $fixtureCleanup `
    -CleanupFailureCode "db24_fixture_cleanup_rejected"
  Assert-Condition -Condition (-not (Test-Path -LiteralPath $fixtureRoot) -and $script:Db24FixtureStartAttemptCount -eq 0) `
    -Code "db24_fixture_final_residue_rejected"
}

function New-Db25SyntheticProcessWithFailingId {
  $model = [pscustomobject]@{ HasExited = $false; KillCount = 0; WaitCount = 0; InputCloseCount = 0 }
  $input = [pscustomobject]@{ Model = $model }
  $input | Add-Member -MemberType ScriptMethod -Name Close -Value { $this.Model.InputCloseCount++ }
  $process = [pscustomobject]@{ Id = 25007; FixtureProcessIdReadFails = $true; Model = $model; StandardInput = $input }
  $process | Add-Member -MemberType ScriptProperty -Name HasExited -Value { [bool]$this.Model.HasExited }
  $process | Add-Member -MemberType ScriptMethod -Name Kill -Value {
    $this.Model.KillCount++
    $this.Model.HasExited = $true
  }
  $process | Add-Member -MemberType ScriptMethod -Name WaitForExit -Value {
    param([int]$TimeoutMilliseconds)
    $this.Model.WaitCount++
    return [bool]$this.Model.HasExited
  }
  return $process
}

function Get-Db25FrozenStateSnapshot {
  param([Parameter(Mandatory = $true)][object]$State)
  return @(
    [string]$State.Path, [string]$State.RunDirectory, [string]$State.CanonicalPath,
    [string]$State.CanonicalRunDirectory, [string]$State.CanonicalFileName,
    [string]$State.ExpectedSha256, [string]$State.ExpectedByteLength,
    [string]$State.IdentityFrozen, [string]$State.OwnerState,
    [string]$State.ProcessStartObserved, [string]$State.ProcessIdObserved,
    [string]$State.CleanupInvocationCount
  ) -join "|"
}

function Assert-Db25VerifiedArtifactAndProcessEscrowFixtures {
  $originalScenario = $script:CurrentScenario
  $fixtureRoot = [System.IO.Path]::GetFullPath((Join-Path $script:EvidenceRoot ("validate-db25-" + [guid]::NewGuid().ToString("N"))))
  $evidenceRoot = [System.IO.Path]::GetFullPath($script:EvidenceRoot).TrimEnd('\', '/') + [System.IO.Path]::DirectorySeparatorChar
  Assert-Condition -Condition ($fixtureRoot.StartsWith($evidenceRoot, [System.StringComparison]::OrdinalIgnoreCase) -and
    (Split-Path -Leaf $fixtureRoot) -cmatch '^validate-db25-[a-f0-9]{32}$') `
    -Code "db25_fixture_root_rejected" -FailureClass "source_integrity_rejection"
  if (-not (Test-Path -LiteralPath $script:EvidenceRoot -PathType Container)) {
    [void](New-Item -ItemType Directory -Path $script:EvidenceRoot -Force)
  }
  [void](New-Item -ItemType Directory -Path $fixtureRoot)
  $fixtureError = $null
  $fixtureScenario = $null
  $script:Db25FixtureStartAttemptCount = 0
  $script:Db25LastCreatedArtifact = $null
  $script:Db25HandoffFault = $null
  $script:Db25StartInfoClearFault = $null
  $script:Db25ProcessIdFault = $null
  $encoding = New-Object System.Text.UTF8Encoding($false)
  try {
    $sql = "select 1;"
    $callerArtifact = New-SqlFile -RunDirectory $fixtureRoot -Label "db25_verified_caller" -Sql $sql -InitialOwner caller
    $controllerArtifact = New-SqlFile -RunDirectory $fixtureRoot -Label "db25_verified_controller" -Sql $sql -InitialOwner controller
    Assert-Condition -Condition ($callerArtifact.Path -ceq $callerArtifact.CanonicalPath -and
      $callerArtifact.CanonicalRunDirectory -ceq [System.IO.Path]::GetFullPath($fixtureRoot).TrimEnd('\', '/') -and
      $callerArtifact.CanonicalFileName -cmatch '^worker_[a-z0-9_]+_[0-9a-f]{32}\.sql$' -and
      $callerArtifact.ExpectedSha256 -ceq (Get-Sha256 -Path $callerArtifact.Path) -and
      [long]$callerArtifact.ExpectedByteLength -eq [long](Get-Item -LiteralPath $callerArtifact.Path -Force).Length -and
      $callerArtifact.OwnershipState.IdentityFrozen -and $callerArtifact.OwnershipState.CallerOwns -and
      $controllerArtifact.OwnershipState.ControllerOwns) -Code "db25_verified_artifact_contract_rejected" `
      -FailureClass "source_integrity_rejection"

    $identitySnapshot = Get-Db25FrozenStateSnapshot -State $callerArtifact.OwnershipState
    foreach ($mutation in @(
      [pscustomobject]@{ Name = "path"; Identity = [pscustomobject]@{
        CanonicalPath = $controllerArtifact.CanonicalPath; CanonicalRunDirectory = $callerArtifact.CanonicalRunDirectory
        CanonicalFileName = $callerArtifact.CanonicalFileName; ExpectedSha256 = $callerArtifact.ExpectedSha256
        ExpectedByteLength = $callerArtifact.ExpectedByteLength }; Code = "psql_disposable_handoff_identity_rejected" },
      [pscustomobject]@{ Name = "directory"; Identity = [pscustomobject]@{
        CanonicalPath = $callerArtifact.CanonicalPath; CanonicalRunDirectory = ($callerArtifact.CanonicalRunDirectory + "-other")
        CanonicalFileName = $callerArtifact.CanonicalFileName; ExpectedSha256 = $callerArtifact.ExpectedSha256
        ExpectedByteLength = $callerArtifact.ExpectedByteLength }; Code = "psql_disposable_handoff_run_directory_rejected" },
      [pscustomobject]@{ Name = "filename"; Identity = [pscustomobject]@{
        CanonicalPath = $callerArtifact.CanonicalPath; CanonicalRunDirectory = $callerArtifact.CanonicalRunDirectory
        CanonicalFileName = ("worker_other_" + [guid]::NewGuid().ToString("N") + ".sql"); ExpectedSha256 = $callerArtifact.ExpectedSha256
        ExpectedByteLength = $callerArtifact.ExpectedByteLength }; Code = "psql_disposable_handoff_filename_rejected" },
      [pscustomobject]@{ Name = "hash"; Identity = [pscustomobject]@{
        CanonicalPath = $callerArtifact.CanonicalPath; CanonicalRunDirectory = $callerArtifact.CanonicalRunDirectory
        CanonicalFileName = $callerArtifact.CanonicalFileName; ExpectedSha256 = ("0" * 64)
        ExpectedByteLength = $callerArtifact.ExpectedByteLength }; Code = "psql_disposable_handoff_hash_rejected" },
      [pscustomobject]@{ Name = "length"; Identity = [pscustomobject]@{
        CanonicalPath = $callerArtifact.CanonicalPath; CanonicalRunDirectory = $callerArtifact.CanonicalRunDirectory
        CanonicalFileName = $callerArtifact.CanonicalFileName; ExpectedSha256 = $callerArtifact.ExpectedSha256
        ExpectedByteLength = ([long]$callerArtifact.ExpectedByteLength + 1) }; Code = "psql_disposable_handoff_length_rejected" }
    )) {
      [void](Invoke-Db24ExpectedFailure -ExpectedCode $mutation.Code -Operation {
        Assert-PsqlDisposableStateIdentity -State $callerArtifact.OwnershipState -Identity $mutation.Identity
      })
      Assert-Condition -Condition ((Get-Db25FrozenStateSnapshot -State $callerArtifact.OwnershipState) -ceq $identitySnapshot) `
        -Code ("db25_failure_atomic_" + $mutation.Name + "_rejected") -FailureClass "source_integrity_rejection"
    }
    [void](Invoke-Db24ExpectedFailure -ExpectedCode "psql_disposable_identity_already_frozen" -Operation {
      Set-PsqlDisposableFrozenIdentity -State $callerArtifact.OwnershipState -Identity $callerArtifact
    })
    Assert-Condition -Condition ((Get-Db25FrozenStateSnapshot -State $callerArtifact.OwnershipState) -ceq $identitySnapshot) `
      -Code "db25_double_freeze_failure_atomic_rejected" -FailureClass "source_integrity_rejection"

    $dummyConnection = [pscustomobject]@{}
    $dummyPsqlPath = "unreachable-psql.exe"
    $script:Db25HandoffFault = "replace_before_invoke"
    $replacementError = Invoke-Db24ExpectedFailure -ExpectedCode "psql_disposable_handoff_hash_rejected" -Operation {
      Invoke-PsqlSql -Connection $dummyConnection -PsqlPath $dummyPsqlPath -Sql $sql `
        -ApplicationName "sitaa_sem01_db25_replace" -RunDirectory $fixtureRoot `
        -StatementTimeoutMilliseconds 570001 -ProcessTimeoutMilliseconds 0
    }
    $script:Db25HandoffFault = $null
    $replacementArtifact = $script:Db25LastCreatedArtifact
    Assert-Condition -Condition ($null -ne $replacementArtifact -and
      $replacementArtifact.ExpectedSha256 -cne (Get-Sha256 -Path $replacementArtifact.Path) -and
      [string]$replacementArtifact.OwnershipState.OwnerState -ceq "caller" -and
      (Test-Path -LiteralPath $replacementArtifact.Path -PathType Leaf) -and
      $script:Db25FixtureStartAttemptCount -eq 0 -and
      [object]::ReferenceEquals($replacementArtifact.OwnershipState.PrimaryErrorRecord.Exception, $replacementError.Exception)) `
      -Code "db25_creation_to_caller_replacement_rejected" -FailureClass "source_integrity_rejection"
    Remove-Item -LiteralPath $replacementArtifact.Path -Force
    $replacementFinalCleanup = Invoke-PsqlDisposableControllerCleanup -State $replacementArtifact.OwnershipState
    Assert-Condition -Condition ($replacementFinalCleanup.Succeeded -and
      [string]$replacementArtifact.OwnershipState.OwnerState -ceq "completed") `
      -Code "db25_replacement_independent_finalizer_rejected" -FailureClass "postcondition_rejection"

    $starterArtifact = New-SqlFile -RunDirectory $fixtureRoot -Label "db25_starter" -Sql $sql -InitialOwner controller
    $starterProcess = New-Db24SyntheticProcess -ProcessId 25001 -TerminationSucceeds $true
    Set-PsqlDisposableStarterOwnership -State $starterArtifact.OwnershipState -Process $starterProcess
    Assert-Condition -Condition ($starterArtifact.OwnershipState.StarterOwns -and
      $starterArtifact.OwnershipState.ProcessStartObserved -and
      [object]::ReferenceEquals($starterArtifact.OwnershipState.Process, $starterProcess) -and
      -not $starterArtifact.OwnershipState.ProcessIdObserved -and $null -eq $starterArtifact.OwnershipState.ProcessId) `
      -Code "db25_immediate_starter_escrow_rejected" -FailureClass "source_integrity_rejection"
    $starterProcess.Model.HasExited = $true
    $starterArtifact.OwnershipState.ProcessTerminationObserved = $true
    [void](Invoke-PsqlDisposableStarterCleanup -State $starterArtifact.OwnershipState)

    $processIdArtifact = New-SqlFile -RunDirectory $fixtureRoot -Label "db25_process_id" -Sql $sql -InitialOwner controller
    $processIdState = New-Db24OwnedFixtureState -Artifact $processIdArtifact
    $processIdProcess = New-Db25SyntheticProcessWithFailingId
    Set-PsqlDisposableStarterOwnership -State $processIdState -Process $processIdProcess
    $processIdPrimary = $null
    try { [void](Get-PsqlProcessId -Process $processIdProcess) }
    catch { $processIdPrimary = $_ }
    $processIdState.PrimaryErrorRecord = $processIdPrimary
    $processIdCleanup = Invoke-PsqlWorkerStartFailureCleanup -State $processIdState -ApplicationName "sitaa_sem01_db25_pid" `
      -RunDirectory $fixtureRoot -WorkerExecutionContext $null -DeleteSqlFileOnCompletion $true `
      -FallbackProcess $processIdProcess -FallbackProcessStarted $true
    Assert-Condition -Condition ($null -ne $processIdPrimary -and
      $processIdPrimary.Exception.Message.Contains("db25_synthetic_process_id_failure")) `
      -Code "db25_process_id_primary_rejected" -FailureClass "source_integrity_rejection"
    Assert-Condition -Condition $processIdCleanup.Succeeded -Code "db25_process_id_cleanup_result_rejected" `
      -FailureClass "source_integrity_rejection"
    Assert-Condition -Condition ($processIdProcess.Model.KillCount -eq 1 -and $processIdState.ProcessTerminationObserved) `
      -Code "db25_process_id_reference_termination_rejected" -FailureClass "source_integrity_rejection"
    Assert-Condition -Condition (-not $processIdState.LocalPidRemovalAttempted -and
      -not $processIdState.ExecutePidRemovalAttempted) -Code "db25_process_id_pid_cleanup_invented" `
      -FailureClass "source_integrity_rejection"
    Assert-Condition -Condition ([string]$processIdState.OwnerState -ceq "completed" -and $null -eq $processIdState.Worker) `
      -Code "db25_process_id_terminal_state_rejected" -FailureClass "source_integrity_rejection"

    $startInfoArtifact = New-SqlFile -RunDirectory $fixtureRoot -Label "db25_start_info" -Sql $sql -InitialOwner controller
    $syntheticConnection = [pscustomobject]@{
      Host = "db25.invalid"; Port = "5432"; User = "db25_user"; Password = "db25_secret"
      Database = "db25_database"; SslMode = "require"
    }
    $normalStartInfo = New-PsqlStartInfo -PsqlPath "psql.exe" -Connection $syntheticConnection `
      -SqlFile $startInfoArtifact.Path -ApplicationName "sitaa_sem01_db25_start_info"
    $normalStartState = New-PsqlProcessStartState -StartInfo $normalStartInfo -RunDirectory $fixtureRoot `
      -ApplicationName "sitaa_sem01_db25_start_info" -WorkerExecutionContext $null
    Clear-PsqlStartInfoMaterial -State $normalStartState -StartInfo $normalStartInfo
    Assert-Condition -Condition ($normalStartState.StartInfoMaterialClearAttempted -and $normalStartState.StartInfoMaterialCleared -and
      -not (Test-PsqlStartInfoContainsPgMaterial -StartInfo $normalStartInfo)) `
      -Code "db25_start_info_normal_clear_rejected" -FailureClass "source_integrity_rejection"

    $failureStartInfo = New-PsqlStartInfo -PsqlPath "psql.exe" -Connection $syntheticConnection `
      -SqlFile $startInfoArtifact.Path -ApplicationName "sitaa_sem01_db25_start_failure"
    $failureStartState = New-PsqlProcessStartState -StartInfo $failureStartInfo -RunDirectory $fixtureRoot `
      -ApplicationName "sitaa_sem01_db25_start_failure" -WorkerExecutionContext $null
    $startInfoPrimary = Invoke-Db24ExpectedFailure -ExpectedCode "db25_start_info_primary" -Operation {
      Throw-StableFailure -Code "db25_start_info_primary" -FailureClass "worker_crash"
    }
    $failureStartState.PrimaryErrorRecord = $startInfoPrimary
    $failureStartCleanup = Invoke-PsqlWorkerStartFailureCleanup -State $failureStartState `
      -ApplicationName "sitaa_sem01_db25_start_failure" -RunDirectory $fixtureRoot -WorkerExecutionContext $null `
      -DeleteSqlFileOnCompletion $false -FallbackProcessStarted $false -FallbackStartInfo $failureStartInfo
    Assert-Condition -Condition ($failureStartCleanup.Succeeded -and $failureStartState.StartInfoMaterialClearAttempted -and
      $failureStartState.StartInfoMaterialCleared -and -not (Test-PsqlStartInfoContainsPgMaterial -StartInfo $failureStartInfo) -and
      [object]::ReferenceEquals($failureStartState.PrimaryErrorRecord.Exception, $startInfoPrimary.Exception)) `
      -Code "db25_start_info_failure_clear_rejected" -FailureClass "source_integrity_rejection"

    $secondaryStartInfo = New-PsqlStartInfo -PsqlPath "psql.exe" -Connection $syntheticConnection `
      -SqlFile $startInfoArtifact.Path -ApplicationName "sitaa_sem01_db25_start_secondary"
    $secondaryStartState = New-PsqlProcessStartState -StartInfo $secondaryStartInfo -RunDirectory $fixtureRoot `
      -ApplicationName "sitaa_sem01_db25_start_secondary" -WorkerExecutionContext $null
    $secondaryStartState.PrimaryErrorRecord = $startInfoPrimary
    $script:Db25StartInfoClearFault = "failure"
    $secondaryStartCleanup = Invoke-PsqlWorkerStartFailureCleanup -State $secondaryStartState `
      -ApplicationName "sitaa_sem01_db25_start_secondary" -RunDirectory $fixtureRoot -WorkerExecutionContext $null `
      -DeleteSqlFileOnCompletion $false -FallbackProcessStarted $false -FallbackStartInfo $secondaryStartInfo
    $script:Db25StartInfoClearFault = $null
    $secondaryCaught = $null
    try {
      Complete-OrchestrationCleanup -PrimaryError $startInfoPrimary -PrimaryScenario $originalScenario `
        -CleanupResult $secondaryStartCleanup -CleanupFailureCode "db25_start_info_secondary_cleanup_rejected"
    }
    catch { $secondaryCaught = $_ }
    Assert-Condition -Condition (-not $secondaryStartCleanup.Succeeded -and
      @($secondaryStartCleanup.SecondaryErrors) -contains "PSQL_START_INFO_CLEAR" -and
      [object]::ReferenceEquals($startInfoPrimary.Exception, $secondaryCaught.Exception)) `
      -Code "db25_start_info_secondary_primary_preservation_rejected" -FailureClass "source_integrity_rejection"
    Clear-PsqlStartInfoMaterial -State $secondaryStartState -StartInfo $secondaryStartInfo
    [void](Invoke-PsqlDisposableControllerCleanup -State $startInfoArtifact.OwnershipState)

    $script:CurrentScenario = "MS07_ADMIN_RPC_REJECTS_HIGH_ISOLATION"
    $script:Db25HandoffFault = "recreate_completed"
    $outerError = Invoke-Db24ExpectedFailure -ExpectedCode "psql_process_timeout_overflow_rejected" -Operation {
      Invoke-PsqlSql -Connection $dummyConnection -PsqlPath $dummyPsqlPath -Sql $sql `
        -ApplicationName "sitaa_sem01_db25_outer" -RunDirectory $fixtureRoot `
        -StatementTimeoutMilliseconds 570001 -ProcessTimeoutMilliseconds 0
    }
    $script:Db25HandoffFault = $null
    $outerArtifact = $script:Db25LastCreatedArtifact
    Assert-Condition -Condition ($null -ne $outerArtifact -and
      [string]$outerArtifact.OwnershipState.OwnerState -ceq "completed" -and
      $outerArtifact.OwnershipState.CleanupInvocationCount -eq 1 -and
      (Test-Path -LiteralPath $outerArtifact.Path -PathType Leaf) -and
      @($outerArtifact.OwnershipState.SecondaryCleanupErrors) -contains "PSQL_HANDOFF_OUTER_CLEANUP" -and
      [object]::ReferenceEquals($outerArtifact.OwnershipState.PrimaryErrorRecord.Exception, $outerError.Exception) -and
      [string]$outerArtifact.OwnershipState.PrimaryFailureClass -ceq "source_integrity_rejection" -and
      [string]$outerArtifact.OwnershipState.PrimaryScenario -ceq "MS07_ADMIN_RPC_REJECTS_HIGH_ISOLATION") `
      -Code "db25_integrated_outer_cleanup_primary_preservation_rejected" -FailureClass "source_integrity_rejection"
    Remove-Item -LiteralPath $outerArtifact.Path -Force
    $script:CurrentScenario = $originalScenario

    $runtimeDefinition = [string](Get-Command Start-StagedRuntimeAdvisoryHolder -CommandType Function).Definition
    $runtimeStartIndex = $runtimeDefinition.IndexOf('Assert-Condition -Condition ($process.Start())', [System.StringComparison]::Ordinal)
    $runtimeLocalProcessIndex = $runtimeDefinition.IndexOf('$processStartState.Process = $process', [System.StringComparison]::Ordinal)
    $runtimeLocalStartedIndex = $runtimeDefinition.IndexOf('$processStartState.ProcessStarted = $true', [System.StringComparison]::Ordinal)
    $runtimeDisposableProcessIndex = $runtimeDefinition.IndexOf('$DisposableSqlOwnershipState.Process = $process', [System.StringComparison]::Ordinal)
    $runtimeStarterIndex = $runtimeDefinition.IndexOf('$DisposableSqlOwnershipState.OwnerState = "starter"', [System.StringComparison]::Ordinal)
    $runtimeIdIndex = $runtimeDefinition.IndexOf('$processId = Get-PsqlProcessId -Process $process', [System.StringComparison]::Ordinal)
    $runtimeReaderIndex = $runtimeDefinition.IndexOf('ReadLineAsync()', [System.StringComparison]::Ordinal)
    $runtimePidIndex = $runtimeDefinition.IndexOf('Update-WorkerPidManifest', [System.StringComparison]::Ordinal)
    $runtimeWorkerIndex = $runtimeDefinition.IndexOf('Set-PsqlDisposableWorkerOwnership', [System.StringComparison]::Ordinal)
    $runtimeReturnIndex = $runtimeDefinition.IndexOf('return $worker', [System.StringComparison]::Ordinal)
    Assert-Condition -Condition ($runtimeStartIndex -ge 0 -and $runtimeLocalProcessIndex -gt $runtimeStartIndex -and
      $runtimeLocalStartedIndex -gt $runtimeLocalProcessIndex -and $runtimeDisposableProcessIndex -gt $runtimeLocalStartedIndex -and
      $runtimeStarterIndex -gt $runtimeDisposableProcessIndex -and $runtimeIdIndex -gt $runtimeStarterIndex -and
      $runtimeReaderIndex -gt $runtimeIdIndex -and $runtimePidIndex -gt $runtimeReaderIndex -and
      $runtimeWorkerIndex -gt $runtimePidIndex -and $runtimeReturnIndex -gt $runtimeWorkerIndex) `
      -Code "db25_staged_runtime_escrow_order_rejected" -FailureClass "source_integrity_rejection"

    $invariantBase = $controllerArtifact.OwnershipState
    foreach ($invalid in @(
      [pscustomobject]@{ Code = "psql_disposable_starter_state_rejected"; Build = {
        $state = $invariantBase.PSObject.Copy(); $state.OwnerState = "starter"; $state.ProcessStartObserved = $true; $state.Process = $null; $state } },
      [pscustomobject]@{ Code = "psql_disposable_prestart_state_rejected"; Build = {
        $state = $invariantBase.PSObject.Copy(); $state.ProcessStartObserved = $true; $state } },
      [pscustomobject]@{ Code = "psql_disposable_worker_state_rejected"; Build = {
        $state = $invariantBase.PSObject.Copy(); $state.OwnerState = "worker"; $state.ProcessStartObserved = $true
        $state.ProcessIdObserved = $true; $state.ProcessId = 25002; $state.Process = New-Db24SyntheticProcess -ProcessId 25002 -TerminationSucceeds $true
        $state.StartInfoMaterialCleared = $true; $state.Worker = $null; $state } },
      [pscustomobject]@{ Code = "psql_disposable_worker_state_rejected"; Build = {
        $state = $invariantBase.PSObject.Copy(); $state.OwnerState = "worker"; $state.ProcessStartObserved = $true
        $state.ProcessIdObserved = $true; $state.ProcessId = 25003; $state.Process = New-Db24SyntheticProcess -ProcessId 25003 -TerminationSucceeds $true
        $state.StartInfoMaterialCleared = $true; $state.Worker = [pscustomobject]@{ Process = (New-Db24SyntheticProcess -ProcessId 25004 -TerminationSucceeds $true); SqlFile = $state.CanonicalPath }; $state } },
      [pscustomobject]@{ Code = "psql_disposable_completed_invariant_rejected"; Build = {
        $state = New-PsqlDisposableOwnershipState -RunDirectory $fixtureRoot; $state.OwnerState = "completed"; $state.CleanupCompleted = $true; $state.AbsenceObserved = $false; $state } },
      [pscustomobject]@{ Code = "psql_disposable_completed_invariant_rejected"; Build = {
        $state = New-PsqlDisposableOwnershipState -RunDirectory $fixtureRoot; $state.OwnerState = "completed"; $state.CleanupCompleted = $true; $state.AbsenceObserved = $true
        $state.ProcessStartObserved = $true; $state.Process = New-Db24SyntheticProcess -ProcessId 25005 -TerminationSucceeds $true; $state } },
      [pscustomobject]@{ Code = "psql_disposable_completed_invariant_rejected"; Build = {
        $state = New-PsqlDisposableOwnershipState -RunDirectory $fixtureRoot; $state.OwnerState = "completed"; $state.CleanupCompleted = $true; $state.AbsenceObserved = $true
        $state.StartInfo = New-PsqlStartInfo -PsqlPath "psql.exe" -Connection $syntheticConnection -SqlFile $script:MigrationPath -ApplicationName "sitaa_sem01_db25_invariant"; $state } }
    )) {
      $invalidState = & $invalid.Build
      [void](Invoke-Db24ExpectedFailure -ExpectedCode $invalid.Code -Operation {
        Assert-PsqlDisposableOwnershipInvariant -State $invalidState
      })
    }

    $protectedHash = Get-Sha256 -Path $script:MigrationPath
    $protectedOwnerState = New-PsqlDisposableOwnershipState -SqlFile $script:MigrationPath -RunDirectory $fixtureRoot
    [void](Invoke-Db24ExpectedFailure -ExpectedCode "psql_process_timeout_overflow_rejected" -Operation {
      Invoke-PsqlFile -Connection $dummyConnection -PsqlPath $dummyPsqlPath -SqlFile $script:MigrationPath `
        -ApplicationName "sitaa_sem01_db25_protected_prestart" -RunDirectory $fixtureRoot `
        -StatementTimeoutMilliseconds 570001 -ProcessTimeoutMilliseconds 0 -DeleteSqlFileOnCompletion $false `
        -DisposableSqlOwnershipState $protectedOwnerState
    })
    $protectedStartInfo = New-PsqlStartInfo -PsqlPath "psql.exe" -Connection $syntheticConnection `
      -SqlFile $script:MigrationPath -ApplicationName "sitaa_sem01_db25_protected_poststart"
    $protectedProcessState = New-PsqlProcessStartState -StartInfo $protectedStartInfo -RunDirectory $fixtureRoot `
      -ApplicationName "sitaa_sem01_db25_protected_poststart" -WorkerExecutionContext $null
    $protectedProcess = New-Db24SyntheticProcess -ProcessId 25006 -TerminationSucceeds $true
    $protectedProcessState.Process = $protectedProcess
    $protectedProcessState.ProcessStartObserved = $true
    $protectedCleanup = Invoke-PsqlWorkerStartFailureCleanup -State $protectedProcessState `
      -ApplicationName "sitaa_sem01_db25_protected_poststart" -RunDirectory $fixtureRoot -WorkerExecutionContext $null `
      -DeleteSqlFileOnCompletion $false -FallbackProcess $protectedProcess -FallbackProcessStarted $true `
      -FallbackStartInfo $protectedStartInfo
    Assert-Condition -Condition ($protectedCleanup.Succeeded -and $protectedProcessState.ProcessTerminationObserved -and
      -not (Test-PsqlStartInfoContainsPgMaterial -StartInfo $protectedStartInfo) -and
      [string]$protectedOwnerState.OwnerState -ceq "none" -and -not $protectedOwnerState.IdentityFrozen -and
      $protectedOwnerState.RemovalAttemptCount -eq 0 -and (Get-Sha256 -Path $script:MigrationPath) -ceq $protectedHash) `
      -Code "db25_protected_sql_contract_rejected" -FailureClass "source_integrity_rejection"

    [void](Invoke-PsqlDisposableControllerCleanup -State $callerArtifact.OwnershipState)
    [void](Invoke-PsqlDisposableControllerCleanup -State $controllerArtifact.OwnershipState)
    Assert-Condition -Condition ($script:Db25FixtureStartAttemptCount -eq 0 -and
      (Get-TransientWorkerSqlFileCount -RunDirectory $fixtureRoot) -eq 0) `
      -Code "db25_fixture_process_or_sql_residue_rejected" -FailureClass "postcondition_rejection"
  }
  catch {
    $fixtureError = $_
    $fixtureScenario = [string]$script:CurrentScenario
  }
  $script:Db25HandoffFault = $null
  $script:Db25StartInfoClearFault = $null
  $script:Db25ProcessIdFault = $null
  $script:Db25LastCreatedArtifact = $null
  $script:CurrentScenario = $originalScenario
  $fixtureCleanup = Invoke-OrchestrationCleanup -CleanupOperations @(
    [pscustomobject]@{ Name = "DB25_FIXTURE_DIRECTORY_REMOVE"; Operation = {
      $validatedRoot = [System.IO.Path]::GetFullPath($fixtureRoot)
      Assert-Condition -Condition ($validatedRoot.StartsWith($evidenceRoot, [System.StringComparison]::OrdinalIgnoreCase) -and
        (Split-Path -Leaf $validatedRoot) -cmatch '^validate-db25-[a-f0-9]{32}$') `
        -Code "db25_fixture_recursive_cleanup_path_rejected" -FailureClass "source_integrity_rejection"
      if (Test-Path -LiteralPath $validatedRoot -PathType Container) {
        Remove-Item -LiteralPath $validatedRoot -Recurse -Force
      }
    } },
    [pscustomobject]@{ Name = "DB25_FIXTURE_DIRECTORY_ABSENT"; Operation = {
      Assert-Condition -Condition (-not (Test-Path -LiteralPath $fixtureRoot)) `
        -Code "db25_fixture_directory_residue_rejected" -FailureClass "postcondition_rejection"
    } }
  )
  Complete-OrchestrationCleanup -PrimaryError $fixtureError -PrimaryScenario $fixtureScenario -CleanupResult $fixtureCleanup `
    -CleanupFailureCode "db25_fixture_cleanup_rejected"
  Assert-Condition -Condition (-not (Test-Path -LiteralPath $fixtureRoot) -and $script:Db25FixtureStartAttemptCount -eq 0) `
    -Code "db25_fixture_final_residue_rejected"
}

function New-Db26WorkerFixtureContext {
  param(
    [Parameter(Mandatory = $true)][object]$Artifact,
    [Parameter(Mandatory = $true)][int]$ProcessId,
    [Parameter(Mandatory = $true)][string]$RunDirectory,
    [Parameter(Mandatory = $true)][bool]$TerminationSucceeds,
    [Parameter(Mandatory = $true)][string]$ApplicationName
  )
  $state = New-Db24OwnedFixtureState -Artifact $Artifact
  $process = New-Db24SyntheticProcess -ProcessId $ProcessId -TerminationSucceeds $TerminationSucceeds
  Set-PsqlDisposableStarterOwnership -State $state -Process $process
  $state.ProcessId = $ProcessId
  $state.ProcessIdObserved = $true
  $state.StartInfo = New-Object System.Diagnostics.ProcessStartInfo
  $state.StartInfoMaterialClearAttempted = $true
  $state.StartInfoMaterialCleared = $true
  $state.LocalPidAddAttempted = $true
  $state.LocalPidRecorded = $true
  $state.ExecutePidAddAttempted = $true
  $state.ExecutePidRecorded = $true
  $fixtureExecutionContext = [pscustomobject]@{ FixtureOnly = $true }
  $worker = [pscustomobject]@{
    Process = $process
    StdoutTask = $null
    StderrTask = $null
    SqlFile = $Artifact.Path
    ApplicationName = $ApplicationName
    RunDirectory = $RunDirectory
    DeleteSqlFileOnCompletion = $true
    ProcessStartState = $state
    DisposableSqlOwnershipState = $state
    ExecutionContext = $fixtureExecutionContext
    StartedAt = [DateTime]::UtcNow
  }
  return [pscustomobject]@{ State = $state; Process = $process; Worker = $worker; ExecutionContext = $fixtureExecutionContext }
}

function New-Db26MarkerFixtureWorker {
  param(
    [Parameter(Mandatory = $true)][ValidateSet("stage_a_sent", "stage_b_sent")][string]$StageState,
    [AllowNull()][string[]]$StdoutLines = @(),
    [AllowNull()][string]$MarkerAfterRead = $null
  )
  $process = [pscustomobject]@{ HasExited = $false }
  $worker = [pscustomobject]@{
    Process = $process
    StdoutLines = New-Object System.Collections.ArrayList
    StderrLines = New-Object System.Collections.ArrayList
    StdoutReadTask = $null
    StderrReadTask = $null
    ReadyMarker = "MS11_HOLDER_OPERATION_READY"
    ReleaseMarker = "MS11_HOLDER_RELEASED"
    StageState = $StageState
    FixtureMarkerAfterReadLine = $MarkerAfterRead
    FixtureMarkerAfterReadInjected = $false
  }
  foreach ($line in @($StdoutLines)) { [void]$worker.StdoutLines.Add([string]$line) }
  return $worker
}

function Assert-Db26WorkerHandoffAndMarkerDeadlineFixtures {
  $originalScenario = $script:CurrentScenario
  $fixtureRoot = [System.IO.Path]::GetFullPath((Join-Path $script:EvidenceRoot ("validate-db26-" + [guid]::NewGuid().ToString("N"))))
  $evidenceRoot = [System.IO.Path]::GetFullPath($script:EvidenceRoot).TrimEnd('\', '/') + [System.IO.Path]::DirectorySeparatorChar
  Assert-Condition -Condition ($fixtureRoot.StartsWith($evidenceRoot, [System.StringComparison]::OrdinalIgnoreCase) -and
    (Split-Path -Leaf $fixtureRoot) -cmatch '^validate-db26-[a-f0-9]{32}$') `
    -Code "db26_fixture_root_rejected" -FailureClass "source_integrity_rejection"
  if (-not (Test-Path -LiteralPath $script:EvidenceRoot -PathType Container)) {
    [void](New-Item -ItemType Directory -Path $script:EvidenceRoot -Force)
  }
  [void](New-Item -ItemType Directory -Path $fixtureRoot)
  $fixtureError = $null
  $fixtureScenario = $null
  $script:Db26FixtureStartAttemptCount = 0
  $script:Db26WorkerTransferFault = $null
  Clear-Db26MonotonicFixtureTimeline
  try {
    $sql = "select 1;"

    $successArtifact = New-SqlFile -RunDirectory $fixtureRoot -Label "db26_successful_transfer" -Sql $sql -InitialOwner controller
    $success = New-Db26WorkerFixtureContext -Artifact $successArtifact -ProcessId 26001 -RunDirectory $fixtureRoot `
      -TerminationSucceeds $true -ApplicationName "sitaa_sem01_db26_success"
    Set-PsqlDisposableWorkerOwnership -State $success.State -Worker $success.Worker
    Assert-Condition -Condition ([string]$success.State.OwnerState -ceq "worker" -and
      $success.State.WorkerTransferCount -eq 1 -and [object]::ReferenceEquals($success.State.Worker, $success.Worker)) `
      -Code "db26_successful_worker_transfer_rejected" -FailureClass "source_integrity_rejection"
    $successCleanup = Invoke-PsqlWorkerStartFailureCleanup -State $success.State -ApplicationName $success.Worker.ApplicationName `
      -RunDirectory $fixtureRoot -WorkerExecutionContext $success.ExecutionContext -DeleteSqlFileOnCompletion $true `
      -FallbackProcess $success.Process -FallbackProcessStarted $true -FallbackStartInfo $success.State.StartInfo
    Assert-Condition -Condition ($successCleanup.Succeeded -and [string]$success.State.OwnerState -ceq "completed" -and
      $success.State.CollectionCount -eq 1 -and $success.State.RemovalAttemptCount -eq 1 -and
      $success.State.FixtureLocalPidRemovalCount -eq 1 -and $success.State.FixtureExecutePidRemovalCount -eq 1) `
      -Code "db26_complete_worker_defensive_cleanup_rejected" -FailureClass "postcondition_rejection"

    $prevalidationArtifact = New-SqlFile -RunDirectory $fixtureRoot -Label "db26_prevalidation" -Sql $sql -InitialOwner controller
    $prevalidation = New-Db26WorkerFixtureContext -Artifact $prevalidationArtifact -ProcessId 26002 -RunDirectory $fixtureRoot `
      -TerminationSucceeds $true -ApplicationName "sitaa_sem01_db26_prevalidation"
    $prevalidationWorker = $prevalidation.Worker.PSObject.Copy()
    $prevalidationWorker.RunDirectory = $fixtureRoot + "-different"
    $prevalidationOwner = [string]$prevalidation.State.OwnerState
    $prevalidationWorkerReference = $prevalidation.State.Worker
    $prevalidationTransferCount = [int]$prevalidation.State.WorkerTransferCount
    [void](Invoke-Db24ExpectedFailure -ExpectedCode "psql_disposable_worker_candidate_rejected" -Operation {
      Set-PsqlDisposableWorkerOwnership -State $prevalidation.State -Worker $prevalidationWorker
    })
    Assert-Condition -Condition ([string]$prevalidation.State.OwnerState -ceq $prevalidationOwner -and
      [object]::ReferenceEquals($prevalidation.State.Worker, $prevalidationWorkerReference) -and
      $prevalidation.State.WorkerTransferCount -eq $prevalidationTransferCount) `
      -Code "db26_worker_prevalidation_failure_atomic_rejected" -FailureClass "source_integrity_rejection"
    $prevalidation.Process.Model.HasExited = $true
    $prevalidation.State.ProcessTerminationObserved = $true
    [void](Invoke-PsqlDisposableStarterCleanup -State $prevalidation.State)

    $rollbackArtifact = New-SqlFile -RunDirectory $fixtureRoot -Label "db26_post_mutation" -Sql $sql -InitialOwner controller
    $rollback = New-Db26WorkerFixtureContext -Artifact $rollbackArtifact -ProcessId 26003 -RunDirectory $fixtureRoot `
      -TerminationSucceeds $true -ApplicationName "sitaa_sem01_db26_post_mutation"
    $rollbackOwner = [string]$rollback.State.OwnerState
    $rollbackWorkerReference = $rollback.State.Worker
    $rollbackTransferCount = [int]$rollback.State.WorkerTransferCount
    $script:Db26WorkerTransferFault = "post_mutation_invariant"
    $rollbackPrimary = Invoke-Db24ExpectedFailure -ExpectedCode "db26_synthetic_worker_post_mutation_invariant_failure" -Operation {
      Set-PsqlDisposableWorkerOwnership -State $rollback.State -Worker $rollback.Worker
    }
    $script:Db26WorkerTransferFault = $null
    Assert-Condition -Condition ([string]$rollback.State.OwnerState -ceq $rollbackOwner -and
      [object]::ReferenceEquals($rollback.State.Worker, $rollbackWorkerReference) -and
      $rollback.State.WorkerTransferCount -eq $rollbackTransferCount -and $rollback.State.StarterOwns) `
      -Code "db26_worker_post_mutation_rollback_rejected" -FailureClass "source_integrity_rejection"
    $rollback.State.PrimaryErrorRecord = $rollbackPrimary
    $rollback.State.PrimaryFailureClass = [string]$rollbackPrimary.Exception.Data["FailureClass"]
    $rollback.State.PrimaryScenario = "DB26_GENERIC_TRANSFER"
    $rollbackCleanup = Invoke-PsqlWorkerStartFailureCleanup -State $rollback.State -ApplicationName $rollback.Worker.ApplicationName `
      -RunDirectory $fixtureRoot -WorkerExecutionContext $rollback.ExecutionContext -DeleteSqlFileOnCompletion $true `
      -FallbackProcess $rollback.Process -FallbackProcessStarted $true -FallbackStartInfo $rollback.State.StartInfo
    Assert-Condition -Condition ($rollbackCleanup.Succeeded -and [string]$rollback.State.OwnerState -ceq "completed" -and
      $rollback.State.LocalPidRemovalAttempted -and $rollback.State.ExecutePidRemovalAttempted -and
      $rollback.State.RemovalAttemptCount -eq 1 -and
      [object]::ReferenceEquals($rollback.State.PrimaryErrorRecord.Exception, $rollbackPrimary.Exception)) `
      -Code "db26_failed_transfer_cleanup_rejected" -FailureClass "postcondition_rejection"

    $stagedArtifact = New-SqlFile -RunDirectory $fixtureRoot -Label "db26_staged_transfer" -Sql $sql -InitialOwner controller
    $staged = New-Db26WorkerFixtureContext -Artifact $stagedArtifact -ProcessId 26004 -RunDirectory $fixtureRoot `
      -TerminationSucceeds $true -ApplicationName "sitaa_sem01_db26_staged"
    $staged.Worker | Add-Member -NotePropertyName StageA -NotePropertyValue "select 'MS13_HOLDER_OPERATION_READY|1';"
    $staged.Worker | Add-Member -NotePropertyName StageB -NotePropertyValue "rollback; select 'MS13_HOLDER_RELEASED|1';"
    $staged.Worker | Add-Member -NotePropertyName StageState -NotePropertyValue "started"
    $staged.Worker | Add-Member -NotePropertyName StdoutReadTask -NotePropertyValue ([pscustomobject]@{ FixtureOnly = $true })
    $staged.Worker | Add-Member -NotePropertyName StderrReadTask -NotePropertyValue ([pscustomobject]@{ FixtureOnly = $true })
    Assert-Condition -Condition ($null -ne $staged.Worker.StdoutReadTask -and $null -ne $staged.Worker.StderrReadTask -and
      -not [string]::IsNullOrWhiteSpace([string]$staged.Worker.StageA) -and
      -not [string]::IsNullOrWhiteSpace([string]$staged.Worker.StageB)) `
      -Code "db26_staged_worker_model_rejected" -FailureClass "source_integrity_rejection"
    $script:CurrentScenario = "MS13_PUBLISH_VERSUS_CALENDAR"
    $script:Db26WorkerTransferFault = "post_mutation_invariant"
    $stagedPrimary = Invoke-Db24ExpectedFailure -ExpectedCode "db26_synthetic_worker_post_mutation_invariant_failure" -Operation {
      Set-PsqlDisposableWorkerOwnership -State $staged.State -Worker $staged.Worker
    }
    $script:Db26WorkerTransferFault = $null
    $staged.State.PrimaryErrorRecord = $stagedPrimary
    $staged.State.PrimaryFailureClass = [string]$stagedPrimary.Exception.Data["FailureClass"]
    $staged.State.PrimaryScenario = [string]$script:CurrentScenario
    $stagedCleanup = Invoke-PsqlWorkerStartFailureCleanup -State $staged.State -ApplicationName $staged.Worker.ApplicationName `
      -RunDirectory $fixtureRoot -WorkerExecutionContext $staged.ExecutionContext -DeleteSqlFileOnCompletion $true `
      -FallbackProcess $staged.Process -FallbackProcessStarted $true -FallbackStartInfo $staged.State.StartInfo
    Assert-Condition -Condition ($stagedCleanup.Succeeded -and [string]$staged.State.OwnerState -ceq "completed" -and
      $null -eq $staged.State.Worker -and [object]::ReferenceEquals($staged.State.PrimaryErrorRecord.Exception, $stagedPrimary.Exception) -and
      [string]$staged.State.PrimaryFailureClass -ceq "postcondition_rejection" -and
      [string]$staged.State.PrimaryScenario -ceq "MS13_PUBLISH_VERSUS_CALENDAR") `
      -Code "db26_staged_transfer_failure_cleanup_rejected" -FailureClass "postcondition_rejection"
    $script:CurrentScenario = $originalScenario

    $failedTerminationArtifact = New-SqlFile -RunDirectory $fixtureRoot -Label "db26_failed_termination" -Sql $sql -InitialOwner controller
    $failedTermination = New-Db26WorkerFixtureContext -Artifact $failedTerminationArtifact -ProcessId 26005 -RunDirectory $fixtureRoot `
      -TerminationSucceeds $false -ApplicationName "sitaa_sem01_db26_failed_termination"
    $terminationPrimary = Invoke-Db24ExpectedFailure -ExpectedCode "db26_failed_termination_primary" -Operation {
      Throw-StableFailure -Code "db26_failed_termination_primary" -FailureClass "worker_crash"
    }
    $failedTermination.State.PrimaryErrorRecord = $terminationPrimary
    $failedTerminationCleanup = Invoke-PsqlWorkerStartFailureCleanup -State $failedTermination.State `
      -ApplicationName $failedTermination.Worker.ApplicationName -RunDirectory $fixtureRoot `
      -WorkerExecutionContext $failedTermination.ExecutionContext -DeleteSqlFileOnCompletion $true `
      -FallbackProcess $failedTermination.Process -FallbackProcessStarted $true -FallbackStartInfo $failedTermination.State.StartInfo
    Assert-Condition -Condition (-not $failedTerminationCleanup.Succeeded -and $failedTermination.State.StarterOwns -and
      -not $failedTermination.State.ProcessTerminationObserved -and $failedTermination.State.LocalPidRecorded -and
      $failedTermination.State.ExecutePidRecorded -and (Test-Path -LiteralPath $failedTerminationArtifact.Path) -and
      $failedTermination.State.RemovalAttemptCount -eq 0 -and -not $failedTermination.State.CleanupCompleted -and
      [object]::ReferenceEquals($failedTermination.State.PrimaryErrorRecord.Exception, $terminationPrimary.Exception)) `
      -Code "db26_failed_termination_diagnostic_state_rejected" -FailureClass "postcondition_rejection"
    $failedTermination.Process.Model.TerminationSucceeds = $true
    $failedTerminationFinalCleanup = Invoke-PsqlWorkerStartFailureCleanup -State $failedTermination.State `
      -ApplicationName $failedTermination.Worker.ApplicationName -RunDirectory $fixtureRoot `
      -WorkerExecutionContext $failedTermination.ExecutionContext -DeleteSqlFileOnCompletion $true `
      -FallbackProcess $failedTermination.Process -FallbackProcessStarted $true -FallbackStartInfo $failedTermination.State.StartInfo
    Assert-Condition -Condition ($failedTerminationFinalCleanup.Succeeded -and
      [string]$failedTermination.State.OwnerState -ceq "completed") `
      -Code "db26_failed_termination_independent_finalizer_rejected" -FailureClass "postcondition_rejection"

    $partialArtifact = New-SqlFile -RunDirectory $fixtureRoot -Label "db26_partial_worker" -Sql $sql -InitialOwner controller
    $partial = New-Db26WorkerFixtureContext -Artifact $partialArtifact -ProcessId 26006 -RunDirectory $fixtureRoot `
      -TerminationSucceeds $true -ApplicationName "sitaa_sem01_db26_partial"
    $partial.State.Worker = [pscustomobject]@{ Process = $partial.Process; SqlFile = $partialArtifact.Path }
    $partial.State.OwnerState = "worker"
    $partial.State.WorkerTransferCount = 1
    $partialCleanup = Invoke-PsqlWorkerStartFailureCleanup -State $partial.State -ApplicationName $partial.Worker.ApplicationName `
      -RunDirectory $fixtureRoot -WorkerExecutionContext $partial.ExecutionContext -DeleteSqlFileOnCompletion $true `
      -FallbackProcess $partial.Process -FallbackProcessStarted $true -FallbackStartInfo $partial.State.StartInfo
    Assert-Condition -Condition (-not $partialCleanup.Succeeded -and $partial.State.ProcessTerminationObserved -and
      (Test-Path -LiteralPath $partialArtifact.Path) -and $partial.State.RemovalAttemptCount -eq 0 -and
      @($partialCleanup.SecondaryErrors) -contains "PSQL_START_WORKER_OWNERSHIP_INTEGRITY" -and
      -not $partial.State.CleanupCompleted) -Code "db26_partial_worker_fail_closed_rejected" `
      -FailureClass "postcondition_rejection"
    $partial.State.Worker = $null
    $partial.State.OwnerState = "starter"
    $partial.State.WorkerTransferCount = 0
    $partial.State.LocalPidAddAttempted = $false
    $partial.State.ExecutePidAddAttempted = $false
    [void](Invoke-PsqlDisposableStarterCleanup -State $partial.State)

    $startDefinition = [string](Get-Command Start-PsqlWorker -CommandType Function).Definition
    $startInfoAssertionIndex = $startDefinition.IndexOf('Test-PsqlStartInfoContainsPgMaterial', [System.StringComparison]::Ordinal)
    $genericTransferIndex = $startDefinition.IndexOf('Set-PsqlDisposableWorkerOwnership', [System.StringComparison]::Ordinal)
    $genericReturnIndex = $startDefinition.IndexOf('return $worker', $genericTransferIndex, [System.StringComparison]::Ordinal)
    Assert-Condition -Condition ($startInfoAssertionIndex -ge 0 -and $genericTransferIndex -gt $startInfoAssertionIndex -and
      $genericReturnIndex -gt $genericTransferIndex -and
      [string]::IsNullOrWhiteSpace($startDefinition.Substring(
        $genericTransferIndex + 'Set-PsqlDisposableWorkerOwnership -State $startState -Worker $worker'.Length,
        $genericReturnIndex - ($genericTransferIndex + 'Set-PsqlDisposableWorkerOwnership -State $startState -Worker $worker'.Length)))) `
      -Code "db26_generic_worker_terminal_order_rejected" -FailureClass "source_integrity_rejection"
    $stagedDefinition = [string](Get-Command Start-StagedRuntimeAdvisoryHolder -CommandType Function).Definition
    $stagedTransferIndex = $stagedDefinition.IndexOf('Set-PsqlDisposableWorkerOwnership', [System.StringComparison]::Ordinal)
    $stagedReturnIndex = $stagedDefinition.IndexOf('return $worker', $stagedTransferIndex, [System.StringComparison]::Ordinal)
    Assert-Condition -Condition ($stagedTransferIndex -ge 0 -and $stagedReturnIndex -gt $stagedTransferIndex -and
      [string]::IsNullOrWhiteSpace($stagedDefinition.Substring(
        $stagedTransferIndex + 'Set-PsqlDisposableWorkerOwnership -State $DisposableSqlOwnershipState -Worker $worker'.Length,
        $stagedReturnIndex - ($stagedTransferIndex + 'Set-PsqlDisposableWorkerOwnership -State $DisposableSqlOwnershipState -Worker $worker'.Length)))) `
      -Code "db26_staged_worker_terminal_order_rejected" -FailureClass "source_integrity_rejection"

    $stageARequest = [pscustomobject]@{ Stage = "A"; SentMonotonicTimestamp = [long]0 }
    $stageBRequest = [pscustomobject]@{ Stage = "B"; SentMonotonicTimestamp = [long]0 }
    $timelyStageA = New-Db26MarkerFixtureWorker -StageState "stage_a_sent" -StdoutLines @("MS11_HOLDER_OPERATION_READY|1")
    Set-Db26MonotonicFixtureTimeline -ElapsedMilliseconds @(999, 999, 999)
    $timelyStageAResult = Wait-StagedRuntimeAdvisoryHolderMarker -Worker $timelyStageA `
      -Marker "MS11_HOLDER_OPERATION_READY" -StageRequest $stageARequest -TimeoutMilliseconds 1000
    Clear-Db26MonotonicFixtureTimeline
    Assert-Condition -Condition ($timelyStageA.StageState -ceq "stage_a_observed" -and
      $timelyStageAResult.CommandElapsedMilliseconds -le 1000 -and
      $timelyStageAResult.ObservedMonotonicTimestamp -gt 0) -Code "db26_marker_999ms_rejected" `
      -FailureClass "source_integrity_rejection"

    $inclusiveBoundary = New-Db26MarkerFixtureWorker -StageState "stage_b_sent" -StdoutLines @("MS11_HOLDER_RELEASED|1")
    Set-Db26MonotonicFixtureTimeline -ElapsedMilliseconds @(1000, 1000, 1000)
    $inclusiveBoundaryResult = Wait-StagedRuntimeAdvisoryHolderMarker -Worker $inclusiveBoundary `
      -Marker "MS11_HOLDER_RELEASED" -StageRequest $stageBRequest -TimeoutMilliseconds 1000
    Clear-Db26MonotonicFixtureTimeline
    Assert-Condition -Condition ($inclusiveBoundaryResult.CommandElapsedMilliseconds -le 1000) `
      -Code "db26_marker_inclusive_1000ms_boundary_rejected" -FailureClass "source_integrity_rejection"

    $lateBeforeRead = New-Db26MarkerFixtureWorker -StageState "stage_b_sent" -StdoutLines @("MS11_HOLDER_RELEASED|1")
    Set-Db26MonotonicFixtureTimeline -ElapsedMilliseconds @(1001)
    [void](Invoke-Db24ExpectedFailure -ExpectedCode "staged_runtime_holder_marker_timeout" -Operation {
      Wait-StagedRuntimeAdvisoryHolderMarker -Worker $lateBeforeRead -Marker "MS11_HOLDER_RELEASED" `
        -StageRequest $stageBRequest -TimeoutMilliseconds 1000
    })
    Clear-Db26MonotonicFixtureTimeline

    $lateAfterRead = New-Db26MarkerFixtureWorker -StageState "stage_a_sent" `
      -MarkerAfterRead "MS11_HOLDER_OPERATION_READY|1"
    Set-Db26MonotonicFixtureTimeline -ElapsedMilliseconds @(999, 1001)
    [void](Invoke-Db24ExpectedFailure -ExpectedCode "staged_runtime_holder_marker_late_response_rejected" -Operation {
      Wait-StagedRuntimeAdvisoryHolderMarker -Worker $lateAfterRead -Marker "MS11_HOLDER_OPERATION_READY" `
        -StageRequest $stageARequest -TimeoutMilliseconds 1000
    })
    Clear-Db26MonotonicFixtureTimeline
    Assert-Condition -Condition ($lateAfterRead.StageState -ceq "stage_a_sent" -and $lateAfterRead.FixtureMarkerAfterReadInjected) `
      -Code "db26_late_stage_a_advanced_rejected" -FailureClass "source_integrity_rejection"

    $lateBeforeReturn = New-Db26MarkerFixtureWorker -StageState "stage_a_sent" -StdoutLines @("MS11_HOLDER_OPERATION_READY|1")
    Set-Db26MonotonicFixtureTimeline -ElapsedMilliseconds @(999, 999, 1001)
    [void](Invoke-Db24ExpectedFailure -ExpectedCode "staged_runtime_holder_marker_late_response_rejected" -Operation {
      Wait-StagedRuntimeAdvisoryHolderMarker -Worker $lateBeforeReturn -Marker "MS11_HOLDER_OPERATION_READY" `
        -StageRequest $stageARequest -TimeoutMilliseconds 1000
    })
    Clear-Db26MonotonicFixtureTimeline
    Assert-Condition -Condition ($lateBeforeReturn.StageState -ceq "stage_a_sent") `
      -Code "db26_parse_late_stage_a_advanced_rejected" -FailureClass "source_integrity_rejection"

    $timelyStageB = New-Db26MarkerFixtureWorker -StageState "stage_b_sent" -StdoutLines @("MS11_HOLDER_RELEASED|1")
    Set-Db26MonotonicFixtureTimeline -ElapsedMilliseconds @(500, 500, 500)
    $timelyStageBResult = Wait-StagedRuntimeAdvisoryHolderMarker -Worker $timelyStageB `
      -Marker "MS11_HOLDER_RELEASED" -StageRequest $stageBRequest -TimeoutMilliseconds 1000
    Clear-Db26MonotonicFixtureTimeline
    Assert-Condition -Condition ($timelyStageBResult.Value -ceq "1" -and $timelyStageB.StageState -ceq "stage_b_sent") `
      -Code "db26_timely_stage_b_rejected" -FailureClass "source_integrity_rejection"

    $lateStageB = New-Db26MarkerFixtureWorker -StageState "stage_b_sent" -MarkerAfterRead "MS11_HOLDER_RELEASED|1"
    Set-Db26MonotonicFixtureTimeline -ElapsedMilliseconds @(999, 1001)
    [void](Invoke-Db24ExpectedFailure -ExpectedCode "staged_runtime_holder_marker_late_response_rejected" -Operation {
      Wait-StagedRuntimeAdvisoryHolderMarker -Worker $lateStageB -Marker "MS11_HOLDER_RELEASED" `
        -StageRequest $stageBRequest -TimeoutMilliseconds 1000
    })
    Clear-Db26MonotonicFixtureTimeline

    $duplicateMarker = New-Db26MarkerFixtureWorker -StageState "stage_b_sent" `
      -StdoutLines @("MS11_HOLDER_RELEASED|1", "MS11_HOLDER_RELEASED|1")
    Set-Db26MonotonicFixtureTimeline -ElapsedMilliseconds @(100, 100)
    [void](Invoke-Db24ExpectedFailure -ExpectedCode "staged_runtime_holder_marker_duplicate_rejected" -Operation {
      Wait-StagedRuntimeAdvisoryHolderMarker -Worker $duplicateMarker -Marker "MS11_HOLDER_RELEASED" `
        -StageRequest $stageBRequest -TimeoutMilliseconds 1000
    })
    Clear-Db26MonotonicFixtureTimeline

    $malformedMarker = New-Db26MarkerFixtureWorker -StageState "stage_b_sent" -StdoutLines @("MS11_HOLDER_RELEASED|0")
    Set-Db26MonotonicFixtureTimeline -ElapsedMilliseconds @(100, 100)
    [void](Invoke-Db24ExpectedFailure -ExpectedCode "staged_runtime_holder_marker_value_rejected" -Operation {
      Wait-StagedRuntimeAdvisoryHolderMarker -Worker $malformedMarker -Marker "MS11_HOLDER_RELEASED" `
        -StageRequest $stageBRequest -TimeoutMilliseconds 1000
    })
    Clear-Db26MonotonicFixtureTimeline

    Assert-Condition -Condition ($script:Db26FixtureStartAttemptCount -eq 0 -and
      (Get-TransientWorkerSqlFileCount -RunDirectory $fixtureRoot) -eq 0 -and
      -not $script:Db26MonotonicFixtureActive) -Code "db26_fixture_process_or_sql_residue_rejected" `
      -FailureClass "postcondition_rejection"
  }
  catch {
    $fixtureError = $_
    $fixtureScenario = [string]$script:CurrentScenario
  }
  $script:Db26WorkerTransferFault = $null
  Clear-Db26MonotonicFixtureTimeline
  $script:CurrentScenario = $originalScenario
  $fixtureCleanup = Invoke-OrchestrationCleanup -CleanupOperations @(
    [pscustomobject]@{ Name = "DB26_FIXTURE_DIRECTORY_REMOVE"; Operation = {
      $validatedRoot = [System.IO.Path]::GetFullPath($fixtureRoot)
      Assert-Condition -Condition ($validatedRoot.StartsWith($evidenceRoot, [System.StringComparison]::OrdinalIgnoreCase) -and
        (Split-Path -Leaf $validatedRoot) -cmatch '^validate-db26-[a-f0-9]{32}$') `
        -Code "db26_fixture_recursive_cleanup_path_rejected" -FailureClass "source_integrity_rejection"
      if (Test-Path -LiteralPath $validatedRoot -PathType Container) {
        Remove-Item -LiteralPath $validatedRoot -Recurse -Force
      }
    } },
    [pscustomobject]@{ Name = "DB26_FIXTURE_DIRECTORY_ABSENT"; Operation = {
      Assert-Condition -Condition (-not (Test-Path -LiteralPath $fixtureRoot)) `
        -Code "db26_fixture_directory_residue_rejected" -FailureClass "postcondition_rejection"
    } }
  )
  Complete-OrchestrationCleanup -PrimaryError $fixtureError -PrimaryScenario $fixtureScenario -CleanupResult $fixtureCleanup `
    -CleanupFailureCode "db26_fixture_cleanup_rejected"
  Assert-Condition -Condition (-not (Test-Path -LiteralPath $fixtureRoot) -and
    $script:Db26FixtureStartAttemptCount -eq 0 -and -not $script:Db26MonotonicFixtureActive) `
    -Code "db26_fixture_final_residue_rejected"
}

function New-SyntheticMs06RollbackHolderState {
  return [pscustomobject]@{
    StageState = "started"
    StageASendCount = 0
    StageBSendCount = 0
    ReadyMarkerObserved = $false
    ReadyWithinDeadline = $false
    ExactReadinessObserved = $false
    FrozenBackendPid = 0
    ContendedRollbackStartCount = 0
    Exact55P03Observed = $false
    PostRejectionHolderObserved = $false
    Post0011FingerprintPreserved = $false
    ReleaseMarkerObserved = $false
    ReleaseWithinDeadline = $false
    HolderActive = $true
    DiagnosticPhaseObserved = $false
    RunIdRejected = $false
    SuccessfulRollbackStartCount = 0
  }
}

function Invoke-SyntheticMs06RollbackHolderTransition {
  param(
    [Parameter(Mandatory = $true)][object]$State,
    [Parameter(Mandatory = $true)][ValidateSet("stage_a", "readiness", "start_contended", "record_55P03", "record_wrong_sqlstate", "record_deadlock", "record_timeout", "post_rejection", "preserve_post0011", "stage_b", "release_marker", "cleanup_complete", "start_successful", "unexpected_success")][string]$Action,
    [AllowNull()][object]$Evidence = $null,
    [double]$ElapsedMilliseconds = 0
  )
  switch ($Action) {
    "stage_a" {
      Assert-Condition -Condition ($State.StageState -ceq "started" -and $State.StageASendCount -eq 0) -Code "ms06_fixture_stage_a_order_rejected"
      $State.StageASendCount++
      $State.StageState = "stage_a_observed"
      $State.ReadyMarkerObserved = $true
      $State.ReadyWithinDeadline = ($ElapsedMilliseconds -le 1000)
      Assert-Condition -Condition $State.ReadyWithinDeadline -Code "ms06_fixture_ready_marker_late_rejected"
    }
    "readiness" {
      Assert-Condition -Condition ($State.StageState -ceq "stage_a_observed" -and $State.ReadyMarkerObserved -and
        $null -ne $Evidence -and (Test-ExactRollbackRelationHolderEvidence -Evidence $Evidence)) `
        -Code "ms06_fixture_exact_readiness_rejected"
      $State.ExactReadinessObserved = $true
      $State.FrozenBackendPid = [int]$Evidence.InternalHolderBackendPid
    }
    "start_contended" {
      Assert-Condition -Condition ($State.ReadyMarkerObserved -and $State.ExactReadinessObserved -and
        $State.ContendedRollbackStartCount -eq 0) -Code "ms06_fixture_contended_start_gate_rejected"
      $State.ContendedRollbackStartCount++
    }
    "record_55P03" {
      Assert-Condition -Condition ($State.ContendedRollbackStartCount -eq 1 -and $State.HolderActive) `
        -Code "ms06_fixture_55p03_without_holder_rejected"
      $State.Exact55P03Observed = $true
    }
    "record_wrong_sqlstate" {
      Throw-StableFailure -Code "ms06_fixture_wrong_sqlstate_rejected" -FailureClass "postcondition_rejection"
    }
    "record_deadlock" {
      Throw-StableFailure -Code "postgres_deadlock_40P01" -FailureClass "postgres_deadlock"
    }
    "record_timeout" {
      Throw-StableFailure -Code "rollback_contended_attempt_unexpected_timeout" -FailureClass "unexpected_timeout"
    }
    "post_rejection" {
      Assert-Condition -Condition ($State.Exact55P03Observed -and $null -ne $Evidence -and
        (Test-ExactRollbackRelationHolderEvidence -Evidence $Evidence -ExpectedBackendPid $State.FrozenBackendPid)) `
        -Code "ms06_fixture_same_holder_rejected"
      $State.PostRejectionHolderObserved = $true
    }
    "preserve_post0011" {
      Assert-Condition -Condition $State.Exact55P03Observed -Code "ms06_fixture_post0011_before_rejection_rejected"
      $State.Post0011FingerprintPreserved = $true
    }
    "stage_b" {
      Assert-Condition -Condition ($State.StageState -ceq "stage_a_observed" -and $State.StageBSendCount -eq 0 -and
        $State.Exact55P03Observed -and $State.PostRejectionHolderObserved -and $State.Post0011FingerprintPreserved) `
        -Code "ms06_fixture_stage_b_gate_rejected"
      $State.StageBSendCount++
      $State.StageState = "stage_b_sent"
    }
    "release_marker" {
      Assert-Condition -Condition ($State.StageState -ceq "stage_b_sent" -and $State.StageBSendCount -eq 1) `
        -Code "ms06_fixture_release_before_stage_b_rejected"
      $State.ReleaseWithinDeadline = ($ElapsedMilliseconds -le 1000)
      Assert-Condition -Condition $State.ReleaseWithinDeadline -Code "ms06_fixture_release_marker_late_rejected"
      $State.ReleaseMarkerObserved = $true
      $State.HolderActive = $false
    }
    "cleanup_complete" {
      Assert-Condition -Condition ($State.ReleaseMarkerObserved -and -not $State.HolderActive) `
        -Code "ms06_fixture_cleanup_before_release_rejected"
      $State.StageState = "completed"
    }
    "start_successful" {
      Assert-Condition -Condition ($State.StageState -ceq "completed" -and $State.SuccessfulRollbackStartCount -eq 0) `
        -Code "ms06_fixture_successful_rollback_before_cleanup_rejected"
      $State.SuccessfulRollbackStartCount++
    }
    "unexpected_success" {
      Assert-Condition -Condition ($State.ContendedRollbackStartCount -eq 1) -Code "ms06_fixture_unexpected_success_without_start_rejected"
      $State.DiagnosticPhaseObserved = $true
      $State.RunIdRejected = $true
      Throw-StableFailure -Code "rollback_contended_attempt_unexpected_success" -FailureClass "postcondition_rejection"
    }
  }
  return $State
}

function Assert-Db27RollbackRelationHolderFixtures {
  $originalScenario = $script:CurrentScenario
  $fixtureRoot = [System.IO.Path]::GetFullPath((Join-Path $script:EvidenceRoot ("validate-db27-" + [guid]::NewGuid().ToString("N"))))
  $evidenceRoot = [System.IO.Path]::GetFullPath($script:EvidenceRoot).TrimEnd('\', '/') + [System.IO.Path]::DirectorySeparatorChar
  Assert-Condition -Condition ($fixtureRoot.StartsWith($evidenceRoot, [System.StringComparison]::OrdinalIgnoreCase) -and
    (Split-Path -Leaf $fixtureRoot) -cmatch '^validate-db27-[a-f0-9]{32}$') `
    -Code "db27_fixture_root_rejected" -FailureClass "source_integrity_rejection"
  if (-not (Test-Path -LiteralPath $script:EvidenceRoot -PathType Container)) { [void](New-Item -ItemType Directory -Path $script:EvidenceRoot -Force) }
  [void](New-Item -ItemType Directory -Path $fixtureRoot)
  $fixtureError = $null
  $fixtureScenario = $null
  Clear-Db26MonotonicFixtureTimeline
  try {
    $holderSql = Get-RollbackRelationHolderStageASql
    Assert-Condition -Condition ($holderSql -notmatch '(?i)\bpg_sleep\s*\(' -and
      $holderSql -notmatch '(?im)^\s*(commit|rollback)\s*;') -Code "db27_fixed_stage_a_contract_rejected"
    $artifact = New-SqlFile -RunDirectory $fixtureRoot -Label "db27_rollback_holder" -Sql $holderSql -InitialOwner controller
    Assert-Condition -Condition ([string]$artifact.ExpectedSha256 -cmatch '^[0-9a-f]{64}$' -and
      [long]$artifact.ExpectedByteLength -gt 0 -and $artifact.OwnershipState.ControllerOwns) `
      -Code "db27_verified_holder_artifact_rejected"
    $artifactCleanup = Invoke-PsqlDisposableControllerCleanup -State $artifact.OwnershipState
    Assert-Condition -Condition ($artifactCleanup.Succeeded -and -not (Test-Path -LiteralPath $artifact.Path)) `
      -Code "db27_verified_holder_artifact_cleanup_rejected"

    $exactEvidence = [pscustomobject]@{
      ExactHolderCount = 1; ExactBackendType = $true; IdleInTransaction = $true; ExactRelationLockCount = 1
      ContendedSessionCount = 0; InternalHolderBackendPid = 27001; LocalHolderProcessAlive = $true
    }
    $state = New-SyntheticMs06RollbackHolderState
    [void](Invoke-Db24ExpectedFailure -ExpectedCode "ms06_fixture_stage_b_gate_rejected" -Operation {
      Invoke-SyntheticMs06RollbackHolderTransition -State $state -Action "stage_b"
    })
    [void](Invoke-SyntheticMs06RollbackHolderTransition -State $state -Action "stage_a" -ElapsedMilliseconds 500)
    [void](Invoke-Db24ExpectedFailure -ExpectedCode "ms06_fixture_stage_a_order_rejected" -Operation {
      Invoke-SyntheticMs06RollbackHolderTransition -State $state -Action "stage_a"
    })
    $state | Add-Member -NotePropertyName SyntheticSchedulingDelayMilliseconds -NotePropertyValue 9001
    Assert-Condition -Condition ($state.HolderActive -and $state.StageState -ceq "stage_a_observed" -and
      $state.SyntheticSchedulingDelayMilliseconds -gt 8000) -Code "db27_holder_auto_release_fixture_rejected"
    [void](Invoke-Db24ExpectedFailure -ExpectedCode "ms06_fixture_contended_start_gate_rejected" -Operation {
      Invoke-SyntheticMs06RollbackHolderTransition -State $state -Action "start_contended"
    })

    foreach ($invalidEvidence in @(
      [pscustomobject]@{ ExactHolderCount = 0; ExactBackendType = $true; IdleInTransaction = $true; ExactRelationLockCount = 1; ContendedSessionCount = 0; InternalHolderBackendPid = 27001; LocalHolderProcessAlive = $true },
      [pscustomobject]@{ ExactHolderCount = 2; ExactBackendType = $true; IdleInTransaction = $true; ExactRelationLockCount = 2; ContendedSessionCount = 0; InternalHolderBackendPid = 27001; LocalHolderProcessAlive = $true },
      [pscustomobject]@{ ExactHolderCount = 1; ExactBackendType = $true; IdleInTransaction = $true; ExactRelationLockCount = 0; ContendedSessionCount = 0; InternalHolderBackendPid = 27001; LocalHolderProcessAlive = $true },
      [pscustomobject]@{ ExactHolderCount = 1; ExactBackendType = $true; IdleInTransaction = $false; ExactRelationLockCount = 1; ContendedSessionCount = 0; InternalHolderBackendPid = 27001; LocalHolderProcessAlive = $true },
      [pscustomobject]@{ ExactHolderCount = 1; ExactBackendType = $true; IdleInTransaction = $true; ExactRelationLockCount = 1; ContendedSessionCount = 0; InternalHolderBackendPid = 27001; LocalHolderProcessAlive = $false }
    )) {
      [void](Invoke-Db24ExpectedFailure -ExpectedCode "ms06_fixture_exact_readiness_rejected" -Operation {
        Invoke-SyntheticMs06RollbackHolderTransition -State $state -Action "readiness" -Evidence $invalidEvidence
      })
      Assert-Condition -Condition ($state.ContendedRollbackStartCount -eq 0) -Code "db27_contended_started_after_invalid_readiness_fixture_rejected"
    }
    [void](Invoke-SyntheticMs06RollbackHolderTransition -State $state -Action "readiness" -Evidence $exactEvidence)
    [void](Invoke-SyntheticMs06RollbackHolderTransition -State $state -Action "start_contended")
    Assert-Condition -Condition ($state.ContendedRollbackStartCount -eq 1) -Code "db27_contended_exact_once_fixture_rejected"
    [void](Invoke-Db24ExpectedFailure -ExpectedCode "ms06_fixture_contended_start_gate_rejected" -Operation {
      Invoke-SyntheticMs06RollbackHolderTransition -State $state -Action "start_contended"
    })
    [void](Invoke-Db24ExpectedFailure -ExpectedCode "ms06_fixture_wrong_sqlstate_rejected" -Operation {
      Invoke-SyntheticMs06RollbackHolderTransition -State $state -Action "record_wrong_sqlstate"
    })
    [void](Invoke-Db24ExpectedFailure -ExpectedCode "postgres_deadlock_40P01" -Operation {
      Invoke-SyntheticMs06RollbackHolderTransition -State $state -Action "record_deadlock"
    })
    [void](Invoke-Db24ExpectedFailure -ExpectedCode "rollback_contended_attempt_unexpected_timeout" -Operation {
      Invoke-SyntheticMs06RollbackHolderTransition -State $state -Action "record_timeout"
    })
    [void](Invoke-SyntheticMs06RollbackHolderTransition -State $state -Action "record_55P03")
    [void](Invoke-Db24ExpectedFailure -ExpectedCode "ms06_fixture_stage_b_gate_rejected" -Operation {
      Invoke-SyntheticMs06RollbackHolderTransition -State $state -Action "stage_b"
    })

    $changedPid = $exactEvidence.PSObject.Copy(); $changedPid.InternalHolderBackendPid = 27002
    [void](Invoke-Db24ExpectedFailure -ExpectedCode "ms06_fixture_same_holder_rejected" -Operation {
      Invoke-SyntheticMs06RollbackHolderTransition -State $state -Action "post_rejection" -Evidence $changedPid
    })
    $lostLock = $exactEvidence.PSObject.Copy(); $lostLock.ExactRelationLockCount = 0
    [void](Invoke-Db24ExpectedFailure -ExpectedCode "ms06_fixture_same_holder_rejected" -Operation {
      Invoke-SyntheticMs06RollbackHolderTransition -State $state -Action "post_rejection" -Evidence $lostLock
    })
    $duplicateReplacement = $exactEvidence.PSObject.Copy(); $duplicateReplacement.ExactHolderCount = 2
    [void](Invoke-Db24ExpectedFailure -ExpectedCode "ms06_fixture_same_holder_rejected" -Operation {
      Invoke-SyntheticMs06RollbackHolderTransition -State $state -Action "post_rejection" -Evidence $duplicateReplacement
    })
    [void](Invoke-SyntheticMs06RollbackHolderTransition -State $state -Action "post_rejection" -Evidence $exactEvidence)
    [void](Invoke-SyntheticMs06RollbackHolderTransition -State $state -Action "preserve_post0011")
    [void](Invoke-SyntheticMs06RollbackHolderTransition -State $state -Action "stage_b")
    [void](Invoke-Db24ExpectedFailure -ExpectedCode "ms06_fixture_stage_b_gate_rejected" -Operation {
      Invoke-SyntheticMs06RollbackHolderTransition -State $state -Action "stage_b"
    })
    [void](Invoke-SyntheticMs06RollbackHolderTransition -State $state -Action "release_marker" -ElapsedMilliseconds 500)
    [void](Invoke-SyntheticMs06RollbackHolderTransition -State $state -Action "cleanup_complete")
    [void](Invoke-SyntheticMs06RollbackHolderTransition -State $state -Action "start_successful")

    $unexpected = New-SyntheticMs06RollbackHolderState
    [void](Invoke-SyntheticMs06RollbackHolderTransition -State $unexpected -Action "stage_a" -ElapsedMilliseconds 1)
    [void](Invoke-SyntheticMs06RollbackHolderTransition -State $unexpected -Action "readiness" -Evidence $exactEvidence)
    [void](Invoke-SyntheticMs06RollbackHolderTransition -State $unexpected -Action "start_contended")
    [void](Invoke-Db24ExpectedFailure -ExpectedCode "rollback_contended_attempt_unexpected_success" -Operation {
      Invoke-SyntheticMs06RollbackHolderTransition -State $unexpected -Action "unexpected_success"
    })
    Assert-Condition -Condition ($unexpected.DiagnosticPhaseObserved -and $unexpected.RunIdRejected -and
      $unexpected.SuccessfulRollbackStartCount -eq 0) -Code "db27_unexpected_success_handling_fixture_rejected"

    foreach ($fixtureCase in @(
      [pscustomobject]@{ Stage = "stage_a_sent"; Marker = "MS06_ROLLBACK_HOLDER_LOCKED"; Line = "MS06_ROLLBACK_HOLDER_LOCKED|1"; Elapsed = 500; ExpectFailure = $false },
      [pscustomobject]@{ Stage = "stage_a_sent"; Marker = "MS06_ROLLBACK_HOLDER_LOCKED"; Line = "MS06_ROLLBACK_HOLDER_LOCKED|1"; Elapsed = 1001; ExpectFailure = $true },
      [pscustomobject]@{ Stage = "stage_b_sent"; Marker = "MS06_ROLLBACK_HOLDER_RELEASED"; Line = "MS06_ROLLBACK_HOLDER_RELEASED|1"; Elapsed = 500; ExpectFailure = $false },
      [pscustomobject]@{ Stage = "stage_b_sent"; Marker = "MS06_ROLLBACK_HOLDER_RELEASED"; Line = "MS06_ROLLBACK_HOLDER_RELEASED|1"; Elapsed = 1001; ExpectFailure = $true }
    )) {
      $worker = New-Db26MarkerFixtureWorker -StageState $fixtureCase.Stage -StdoutLines @($fixtureCase.Line)
      $worker.ReadyMarker = "MS06_ROLLBACK_HOLDER_LOCKED"; $worker.ReleaseMarker = "MS06_ROLLBACK_HOLDER_RELEASED"
      $requestStage = if ($fixtureCase.Stage -ceq "stage_a_sent") { "A" } else { "B" }
      $request = [pscustomobject]@{ Stage = $requestStage; SentMonotonicTimestamp = [long]0 }
      Set-Db26MonotonicFixtureTimeline -ElapsedMilliseconds @($fixtureCase.Elapsed, $fixtureCase.Elapsed, $fixtureCase.Elapsed)
      if ($fixtureCase.ExpectFailure) {
        [void](Invoke-Db24ExpectedFailure -ExpectedCode "staged_runtime_holder_marker_timeout" -Operation {
          Wait-StagedRollbackRelationHolderMarker -Worker $worker -Marker $fixtureCase.Marker -StageRequest $request -TimeoutMilliseconds 1000
        })
      }
      else {
        $markerResult = Wait-StagedRollbackRelationHolderMarker -Worker $worker -Marker $fixtureCase.Marker -StageRequest $request -TimeoutMilliseconds 1000
        Assert-Condition -Condition ($markerResult.Value -ceq "1") -Code "db27_timely_marker_fixture_rejected"
      }
      Clear-Db26MonotonicFixtureTimeline
    }
    $duplicateMarker = New-Db26MarkerFixtureWorker -StageState "stage_b_sent" -StdoutLines @("MS06_ROLLBACK_HOLDER_RELEASED|1", "MS06_ROLLBACK_HOLDER_RELEASED|1")
    $duplicateMarker.ReadyMarker = "MS06_ROLLBACK_HOLDER_LOCKED"; $duplicateMarker.ReleaseMarker = "MS06_ROLLBACK_HOLDER_RELEASED"
    Set-Db26MonotonicFixtureTimeline -ElapsedMilliseconds @(1, 1)
    [void](Invoke-Db24ExpectedFailure -ExpectedCode "staged_runtime_holder_marker_duplicate_rejected" -Operation {
      Wait-StagedRollbackRelationHolderMarker -Worker $duplicateMarker -Marker "MS06_ROLLBACK_HOLDER_RELEASED" `
        -StageRequest ([pscustomobject]@{ Stage = "B"; SentMonotonicTimestamp = [long]0 }) -TimeoutMilliseconds 1000
    })
    Clear-Db26MonotonicFixtureTimeline
    $malformedMarker = New-Db26MarkerFixtureWorker -StageState "stage_b_sent" -StdoutLines @("MS06_ROLLBACK_HOLDER_RELEASED|0")
    $malformedMarker.ReadyMarker = "MS06_ROLLBACK_HOLDER_LOCKED"; $malformedMarker.ReleaseMarker = "MS06_ROLLBACK_HOLDER_RELEASED"
    Set-Db26MonotonicFixtureTimeline -ElapsedMilliseconds @(1, 1)
    [void](Invoke-Db24ExpectedFailure -ExpectedCode "staged_runtime_holder_marker_value_rejected" -Operation {
      Wait-StagedRollbackRelationHolderMarker -Worker $malformedMarker -Marker "MS06_ROLLBACK_HOLDER_RELEASED" `
        -StageRequest ([pscustomobject]@{ Stage = "B"; SentMonotonicTimestamp = [long]0 }) -TimeoutMilliseconds 1000
    })
    Clear-Db26MonotonicFixtureTimeline

    $cleanupPrimary = Invoke-Db24ExpectedFailure -ExpectedCode "db27_primary_ms06_failure" -Operation {
      Throw-StableFailure -Code "db27_primary_ms06_failure" -FailureClass "postcondition_rejection"
    }
    $cleanupState = [pscustomobject]@{ HolderAttempts = 0; ContendedAttempts = 0 }
    $cleanup = Invoke-OrchestrationCleanup -CleanupOperations @(
      [pscustomobject]@{ Name = "DB27_HOLDER_CLEANUP"; Operation = { $cleanupState.HolderAttempts++; throw "db27_holder_cleanup_failure" } },
      [pscustomobject]@{ Name = "DB27_CONTENDED_CLEANUP"; Operation = { $cleanupState.ContendedAttempts++ } }
    )
    $rethrow = $null
    try { Complete-OrchestrationCleanup -PrimaryError $cleanupPrimary -PrimaryScenario "MS06_ROLLBACK_PINS_READ_COMMITTED" -CleanupResult $cleanup -CleanupFailureCode "db27_cleanup_rejected" }
    catch { $rethrow = $_ }
    Assert-Condition -Condition ($cleanupState.HolderAttempts -eq 1 -and $cleanupState.ContendedAttempts -eq 1 -and
      $null -ne $rethrow -and [object]::ReferenceEquals($rethrow.Exception, $cleanupPrimary.Exception)) `
      -Code "db27_independent_cleanup_primary_preservation_rejected"

    Assert-Condition -Condition ((Get-TransientWorkerSqlFileCount -RunDirectory $fixtureRoot) -eq 0 -and
      -not $script:Db26MonotonicFixtureActive) -Code "db27_fixture_residue_rejected"
  }
  catch {
    $fixtureError = $_
    $fixtureScenario = [string]$script:CurrentScenario
  }
  Clear-Db26MonotonicFixtureTimeline
  $script:CurrentScenario = $originalScenario
  $fixtureCleanup = Invoke-OrchestrationCleanup -CleanupOperations @(
    [pscustomobject]@{ Name = "DB27_FIXTURE_DIRECTORY_REMOVE"; Operation = {
      $validatedRoot = [System.IO.Path]::GetFullPath($fixtureRoot)
      Assert-Condition -Condition ($validatedRoot.StartsWith($evidenceRoot, [System.StringComparison]::OrdinalIgnoreCase) -and
        (Split-Path -Leaf $validatedRoot) -cmatch '^validate-db27-[a-f0-9]{32}$') `
        -Code "db27_fixture_cleanup_path_rejected" -FailureClass "source_integrity_rejection"
      if (Test-Path -LiteralPath $validatedRoot -PathType Container) { Remove-Item -LiteralPath $validatedRoot -Recurse -Force }
    } },
    [pscustomobject]@{ Name = "DB27_FIXTURE_DIRECTORY_ABSENT"; Operation = {
      Assert-Condition -Condition (-not (Test-Path -LiteralPath $fixtureRoot)) -Code "db27_fixture_directory_residue_rejected"
    } }
  )
  Complete-OrchestrationCleanup -PrimaryError $fixtureError -PrimaryScenario $fixtureScenario -CleanupResult $fixtureCleanup `
    -CleanupFailureCode "db27_fixture_cleanup_rejected"
  Assert-Condition -Condition (-not (Test-Path -LiteralPath $fixtureRoot) -and -not $script:Db26MonotonicFixtureActive) `
    -Code "db27_fixture_final_residue_rejected"
}

function Assert-Ms20CandidateSetContractFixtures {
  $first = (@("11111111", "1111", "4111", "8111", "111111111111") -join "-")
  $second = (@("22222222", "2222", "4222", "8222", "222222222222") -join "-")
  $oneCandidate = [pscustomobject]@{
    CandidateCount = 1; CandidateSetHash = ("a" * 32); SelectedCandidateCount = 1; SelectedCandidateId = $first
    CandidatesAllSynthetic = $true; CandidatesExcludeExactActiveAdmins = $true
  }
  [void](Assert-Ms20CandidateSetState -State $oneCandidate)
  $multipleCandidates = $oneCandidate.PSObject.Copy()
  $multipleCandidates.CandidateCount = 2
  $multipleCandidates.CandidateSetHash = ("b" * 32)
  [void](Assert-Ms20CandidateSetState -State $multipleCandidates)
  Assert-Condition -Condition ((Select-DeterministicMs20CandidateId -CandidateIds @($second, $first)) -ceq $first) `
    -Code "ms20_candidate_deterministic_order_fixture_rejected"

  $zeroCandidates = $oneCandidate.PSObject.Copy()
  $zeroCandidates.CandidateCount = 0
  Assert-LocalStableFailure -ExpectedCode "ms20_candidate_missing" -Operation { [void](Assert-Ms20CandidateSetState -State $zeroCandidates) }
  $malformedHash = $oneCandidate.PSObject.Copy()
  $malformedHash.CandidateSetHash = "INVALID"
  Assert-LocalStableFailure -ExpectedCode "ms20_candidate_set_hash_rejected" -Operation { [void](Assert-Ms20CandidateSetState -State $malformedHash) }

  $frozen = [pscustomobject]@{ Ms20CandidateCount = 2; Ms20CandidateSetHash = ("b" * 32) }
  Assert-Condition -Condition (Test-Ms20CandidateSetMatchesFrozen -State $multipleCandidates -FrozenFingerprint $frozen) `
    -Code "ms20_candidate_restored_fixture_rejected"
  $countDrift = $multipleCandidates.PSObject.Copy()
  $countDrift.CandidateCount = 1
  Assert-Condition -Condition (-not (Test-Ms20CandidateSetMatchesFrozen -State $countDrift -FrozenFingerprint $frozen)) `
    -Code "ms20_candidate_count_drift_fixture_rejected"
  $hashDrift = $multipleCandidates.PSObject.Copy()
  $hashDrift.CandidateSetHash = ("c" * 32)
  Assert-Condition -Condition (-not (Test-Ms20CandidateSetMatchesFrozen -State $hashDrift -FrozenFingerprint $frozen)) `
    -Code "ms20_candidate_hash_drift_fixture_rejected"

  $sanitizedLines = @("MS20_SYNTHETIC_NONADMIN_CANDIDATES|2", "MS20_CANDIDATE_SET|APPROVED")
  Assert-Condition -Condition (-not (Test-ForbiddenEvidence -Lines $sanitizedLines)) -Code "ms20_candidate_sanitized_evidence_fixture_rejected"
  Assert-Condition -Condition (($sanitizedLines -join "|") -notmatch [regex]::Escape($first) -and
    ($sanitizedLines -join "|") -notmatch '@example\.invalid') -Code "ms20_candidate_identity_leak_fixture_rejected"
}

function Assert-PgOptionsContractFixtures {
  $connection = [pscustomobject]@{
    Host = "fixture.invalid"; Port = "5432"; User = "fixture_user"; Password = "fixture_secret"
    Database = "fixture_database"; SslMode = "require"
  }
  foreach ($fixture in @(
    [pscustomobject]@{ Isolation = "read committed"; Encoded = "read\ committed" },
    [pscustomobject]@{ Isolation = "repeatable read"; Encoded = "repeatable\ read" }
  )) {
    $info = New-PsqlStartInfo -PsqlPath "psql.exe" -Connection $connection -SqlFile "fixture.sql" -ApplicationName "sitaa_sem01_pgoptions_fixture" -DefaultIsolation $fixture.Isolation
    $options = [string]$info.EnvironmentVariables["PGOPTIONS"]
    Assert-Condition -Condition ($options -ceq ("-c statement_timeout=45000 -c lock_timeout=15000 -c default_transaction_isolation=" + $fixture.Encoded)) -Code "pgoptions_encoding_fixture_rejected"
    Assert-Condition -Condition (-not $options.Contains("default_transaction_isolation=" + $fixture.Isolation)) -Code "pgoptions_raw_isolation_fixture_rejected"
    Assert-Condition -Condition ($options.Contains("statement_timeout=45000") -and $options.Contains("lock_timeout=15000")) -Code "pgoptions_timeout_fixture_rejected"
    Assert-Condition -Condition (-not $options.Contains([string]$connection.Password) -and -not $options.Contains([string]$connection.Host)) -Code "pgoptions_credential_fixture_rejected"
    Clear-ChildPgEnvironment -StartInfo $info
  }
  Assert-LocalStableFailure -ExpectedCode "pgoptions_isolation_rejected" -Operation { [void](ConvertTo-PgOptionsValue -Value "serializable") }
  Assert-LocalStableFailure -ExpectedCode "pgoptions_value_control_character_rejected" -Operation { [void](ConvertTo-PgOptionsValue -Value "read`ncommitted") }
  Assert-LocalStableFailure -ExpectedCode "pgoptions_value_option_like_rejected" -Operation { [void](ConvertTo-PgOptionsValue -Value "read -c") }
}

function Get-InstallationMigrationTimeoutContractFromSource {
  param([Parameter(Mandatory = $true)][string]$Source)
  $normalized = $Source.Replace("`r`n", "`n").Replace("`r", "`n")
  $lockMatches = [regex]::Matches($normalized, "(?m)^[ `t]*set local lock_timeout = '([1-9][0-9]*)s';[ `t]*$")
  $statementMatches = [regex]::Matches($normalized, "(?m)^[ `t]*set local statement_timeout = '([1-9][0-9]*)s';[ `t]*$")
  Assert-Condition -Condition ($lockMatches.Count -eq 1) -Code "installation_migration_lock_timeout_source_rejected" -FailureClass "source_integrity_rejection"
  Assert-Condition -Condition ($statementMatches.Count -eq 1) -Code "installation_migration_statement_timeout_source_rejected" -FailureClass "source_integrity_rejection"
  $lockMilliseconds = [int]$lockMatches[0].Groups[1].Value * 1000
  $statementMilliseconds = [int]$statementMatches[0].Groups[1].Value * 1000
  Assert-Condition -Condition ($lockMilliseconds -eq 5000) -Code "installation_migration_lock_timeout_source_rejected" -FailureClass "source_integrity_rejection"
  Assert-Condition -Condition ($statementMilliseconds -eq 120000) -Code "installation_migration_statement_timeout_source_rejected" -FailureClass "source_integrity_rejection"
  return [pscustomobject]@{ LockTimeoutMilliseconds = $lockMilliseconds; StatementTimeoutMilliseconds = $statementMilliseconds }
}

function Assert-InstallationTimingContract {
  param(
    [ValidateRange(1, 600000)][int]$MigrationLockTimeoutMilliseconds = $script:InstallationMigrationLockTimeoutMilliseconds,
    [ValidateRange(1, 600000)][int]$MigrationStatementTimeoutMilliseconds = $script:InstallationMigrationStatementTimeoutMilliseconds,
    [ValidateRange(1, 600000)][int]$WaitAgeLimitMilliseconds = $script:InstallationWaitAgeLimitMilliseconds,
    [ValidateRange(1, 600000)][int]$HolderCommitBudgetMilliseconds = $script:InstallationHolderCommitBudgetMilliseconds,
    [ValidateRange(1, 600000)][int]$SafetyIntervalMilliseconds = $script:InstallationSafetyIntervalMilliseconds,
    [ValidateRange(1, 600000)][int]$MigrationCompletionTimeoutMilliseconds = $script:InstallationMigrationCompletionTimeoutMilliseconds,
    [ValidateRange(1, 600000)][int]$HolderProcessExitTimeoutMilliseconds = $script:InstallationHolderProcessExitTimeoutMilliseconds,
    [ValidateRange(1, 600000)][int]$WaitStartDeadlineMilliseconds = $script:InstallationWaitStartDeadlineMilliseconds
  )
  Assert-Condition -Condition ($MigrationLockTimeoutMilliseconds -eq 5000) -Code "installation_migration_lock_timeout_contract_rejected" -FailureClass "source_integrity_rejection"
  Assert-Condition -Condition ($MigrationStatementTimeoutMilliseconds -eq 120000) -Code "installation_migration_statement_timeout_contract_rejected" -FailureClass "source_integrity_rejection"
  Assert-Condition -Condition ($WaitAgeLimitMilliseconds -eq 2000) -Code "installation_wait_age_limit_rejected" -FailureClass "source_integrity_rejection"
  Assert-Condition -Condition ($HolderCommitBudgetMilliseconds -eq 2000) -Code "installation_holder_commit_budget_rejected" -FailureClass "source_integrity_rejection"
  Assert-Condition -Condition ($SafetyIntervalMilliseconds -ge 1000 -and $SafetyIntervalMilliseconds -lt $MigrationLockTimeoutMilliseconds) -Code "installation_safety_interval_rejected" -FailureClass "source_integrity_rejection"
  $serverStructuralBudgetMilliseconds = $MigrationLockTimeoutMilliseconds - $SafetyIntervalMilliseconds
  Assert-Condition -Condition ($serverStructuralBudgetMilliseconds -eq 4000 -and $WaitAgeLimitMilliseconds -le $serverStructuralBudgetMilliseconds) -Code "installation_lock_budget_consumed" -FailureClass "source_integrity_rejection"
  Assert-Condition -Condition ($MigrationCompletionTimeoutMilliseconds -gt $MigrationStatementTimeoutMilliseconds -and $MigrationCompletionTimeoutMilliseconds -ge 130000 -and $MigrationCompletionTimeoutMilliseconds -le 240000) -Code "installation_migration_completion_timeout_rejected" -FailureClass "source_integrity_rejection"
  Assert-Condition -Condition ($HolderProcessExitTimeoutMilliseconds -ge 5000 -and $HolderProcessExitTimeoutMilliseconds -le 30000) -Code "installation_holder_process_exit_timeout_rejected" -FailureClass "source_integrity_rejection"
  Assert-Condition -Condition ($WaitStartDeadlineMilliseconds -ge 10000 -and $WaitStartDeadlineMilliseconds -le 60000) -Code "installation_wait_start_deadline_contract_rejected" -FailureClass "source_integrity_rejection"
  Assert-Condition -Condition ($script:InstallationServerClockRoundingToleranceMilliseconds -ge 0 -and $script:InstallationServerClockRoundingToleranceMilliseconds -le 2) -Code "installation_server_clock_tolerance_rejected" -FailureClass "source_integrity_rejection"
}

function Test-InstallationObservationAccepted {
  param([Parameter(Mandatory = $true)][object]$Observation)
  return ($Observation.WaitObserved -and $Observation.ServerWaitAgeMilliseconds -ge 0 -and
    $Observation.ServerWaitAgeMilliseconds -le $script:InstallationWaitAgeLimitMilliseconds -and
    $Observation.ControllerObservationElapsedMilliseconds -ge 0 -and
    $Observation.ControllerObservationElapsedMilliseconds -lt $script:InstallationWaitStartDeadlineMilliseconds -and
    $Observation.CommandElapsedMilliseconds -ge 0 -and
    $Observation.CommandElapsedMilliseconds -le $script:InstallationObserverCommandTimeoutMilliseconds -and
    (Test-InstallationServerClockTupleAccepted -ServerWaitAgeMilliseconds $Observation.ServerWaitAgeMilliseconds `
      -LockQueryStartEpochMilliseconds $Observation.LockQueryStartEpochMilliseconds -ObservationEpochMilliseconds $Observation.ObservationEpochMilliseconds) -and
    $Observation.MigrationActivitiesWaitUnGranted -and $Observation.HolderLockGranted -and
    $Observation.AcademicPeriodsAccessExclusiveAbsent -and $Observation.HolderAlive -and $Observation.MigrationAlive)
}

function Test-InstallationServerClockTupleAccepted {
  param(
    [long]$ServerWaitAgeMilliseconds,
    [long]$LockQueryStartEpochMilliseconds,
    [long]$ObservationEpochMilliseconds
  )
  if ($ServerWaitAgeMilliseconds -lt 0 -or $LockQueryStartEpochMilliseconds -le 0 -or $ObservationEpochMilliseconds -lt $LockQueryStartEpochMilliseconds) {
    return $false
  }
  $serverDelta = $ObservationEpochMilliseconds - $LockQueryStartEpochMilliseconds
  return ([Math]::Abs([double]($serverDelta - $ServerWaitAgeMilliseconds)) -le $script:InstallationServerClockRoundingToleranceMilliseconds)
}

function Get-ServerClockStructuralTiming {
  param(
    [Parameter(Mandatory = $true)][object]$Observation,
    [Parameter(Mandatory = $true)][long]$CommitMarkerEpochMilliseconds
  )
  Assert-Condition -Condition (Test-InstallationServerClockTupleAccepted -ServerWaitAgeMilliseconds $Observation.ServerWaitAgeMilliseconds `
    -LockQueryStartEpochMilliseconds $Observation.LockQueryStartEpochMilliseconds -ObservationEpochMilliseconds $Observation.ObservationEpochMilliseconds) `
    -Code "installation_wait_server_clock_inconsistent" -FailureClass "source_integrity_rejection"
  Assert-Condition -Condition ($CommitMarkerEpochMilliseconds -ge $Observation.ObservationEpochMilliseconds) -Code "installation_commit_server_clock_order_rejected" -FailureClass "source_integrity_rejection"
  $elapsed = $CommitMarkerEpochMilliseconds - $Observation.LockQueryStartEpochMilliseconds
  Assert-Condition -Condition ($elapsed -ge 0) -Code "installation_structural_server_delta_rejected" -FailureClass "source_integrity_rejection"
  return [pscustomobject]@{
    StructuralWaitThroughCommitMarkerMilliseconds = [long]$elapsed
    WithinBudget = ($elapsed -le ($script:InstallationMigrationLockTimeoutMilliseconds - $script:InstallationSafetyIntervalMilliseconds))
  }
}

function Test-MigrationCompletionAccepted {
  param([bool]$LockAcquiredWithinBudget, [bool]$TimedOut, [int]$ExitCode)
  return ($LockAcquiredWithinBudget -and -not $TimedOut -and $ExitCode -eq 0)
}

function Test-InstallationObservationSequenceAccepted {
  param([Parameter(Mandatory = $true)][object[]]$Samples)
  return ($Samples.Count -ge 2 -and -not $Samples[0].WaitObserved -and
    $Samples[0].ControllerObservationElapsedMilliseconds -lt $script:InstallationWaitStartDeadlineMilliseconds -and
    (Test-InstallationObservationAccepted -Observation $Samples[$Samples.Count - 1]))
}

function Test-TransactionMarkerOrdering {
  param([long]$StageBSentMonotonicTimestamp, [long]$PeriodReadObservedMonotonicTimestamp, [long]$CommitObservedMonotonicTimestamp)
  return ($StageBSentMonotonicTimestamp -ge 0 -and $PeriodReadObservedMonotonicTimestamp -ge $StageBSentMonotonicTimestamp -and
    $CommitObservedMonotonicTimestamp -ge $PeriodReadObservedMonotonicTimestamp)
}

function Assert-InstallationLockBudgetFixtures {
  $migrationSource = [System.IO.File]::ReadAllText($script:MigrationPath, [System.Text.Encoding]::UTF8)
  $timeouts = Get-InstallationMigrationTimeoutContractFromSource -Source $migrationSource
  Assert-Condition -Condition ($timeouts.LockTimeoutMilliseconds -eq $script:InstallationMigrationLockTimeoutMilliseconds -and $timeouts.StatementTimeoutMilliseconds -eq $script:InstallationMigrationStatementTimeoutMilliseconds) -Code "installation_migration_timeout_drift" -FailureClass "source_integrity_rejection"
  Assert-InstallationTimingContract
  Assert-LocalStableFailure -ExpectedCode "installation_migration_lock_timeout_source_rejected" -Operation {
    [void](Get-InstallationMigrationTimeoutContractFromSource -Source ($migrationSource.Replace("set local lock_timeout = '5s';", "set local lock_timeout = '6s';")))
  }
  Assert-LocalStableFailure -ExpectedCode "installation_migration_statement_timeout_source_rejected" -Operation {
    [void](Get-InstallationMigrationTimeoutContractFromSource -Source ($migrationSource.Replace("set local statement_timeout = '120s';", "set local statement_timeout = '121s';")))
  }
  Assert-LocalStableFailure -ExpectedCode "installation_lock_budget_consumed" -Operation {
    Assert-InstallationTimingContract -WaitAgeLimitMilliseconds 2000 -HolderCommitBudgetMilliseconds 2000 -SafetyIntervalMilliseconds 1500
  }
  Assert-LocalStableFailure -ExpectedCode "installation_migration_completion_timeout_rejected" -Operation {
    Assert-InstallationTimingContract -MigrationCompletionTimeoutMilliseconds 120000
  }
}

function Assert-StagedWorkerContractFixtures {
  $fixture = [pscustomobject]@{ StageState = "started" }
  Assert-LocalStableFailure -ExpectedCode "staged_worker_stage_b_rejected" -Operation {
    [void](Get-StagedWorkerNextState -CurrentState $fixture.StageState -Stage "B" -ProcessHasExited $false)
  }
  $fixture.StageState = Get-StagedWorkerNextState -CurrentState $fixture.StageState -Stage "A" -ProcessHasExited $false
  Confirm-StagedWorkerStageA -Worker $fixture -ProcessHasExited $false
  $fixture.StageState = Get-StagedWorkerNextState -CurrentState $fixture.StageState -Stage "B" -ProcessHasExited $false
  Assert-LocalStableFailure -ExpectedCode "staged_worker_stage_b_rejected" -Operation {
    [void](Get-StagedWorkerNextState -CurrentState $fixture.StageState -Stage "B" -ProcessHasExited $false)
  }
  Assert-LocalStableFailure -ExpectedCode "staged_worker_already_completed" -Operation {
    [void](Get-StagedWorkerNextState -CurrentState "stage_a_observed" -Stage "B" -ProcessHasExited $true)
  }
  Assert-Condition -Condition (-not (Test-StagedWorkerPidRemovalEligible -ProcessHasExited $false)) -Code "failed_staged_worker_untracked_before_termination"
  Assert-Condition -Condition (Test-StagedWorkerPidRemovalEligible -ProcessHasExited $true) -Code "terminated_staged_worker_remained_tracked"
}

function Assert-InstallationObserverContractFixtures {
  $connection = [pscustomobject]@{
    Host = "fixture.invalid"; Port = "5432"; User = "fixture_user"; Password = "fixture_secret"
    Database = "fixture_database"; SslMode = "require"
  }
  $info = New-StagedPsqlStartInfo -PsqlPath "psql.exe" -Connection $connection -ApplicationName "sitaa_sem01_install_observer" `
    -StatementTimeoutMilliseconds $script:InstallationObserverCommandTimeoutMilliseconds -LockTimeoutMilliseconds $script:InstallationObserverCommandTimeoutMilliseconds -ReadOnly
  Assert-Condition -Condition ($info.RedirectStandardInput -and ([string]$info.EnvironmentVariables["PGOPTIONS"]).Contains("default_transaction_read_only=on")) -Code "installation_observer_read_only_fixture_rejected"
  $waitSql = Get-InstallationObserverSql -Command "wait_direction"
  Assert-Condition -Condition ($waitSql.Contains("ShareRowExclusiveLock") -and $waitSql.Contains("RowExclusiveLock") -and $waitSql.Contains("AccessExclusiveLock") -and $waitSql.Contains("query_start") -and $waitSql.Contains("observation_epoch_ms") -and $waitSql.Contains("INSTALLATION_WAIT_DIRECTION|1|")) -Code "installation_observer_sql_fixture_rejected"
  Assert-Condition -Condition (-not $waitSql.Contains([string]$connection.Password) -and -not $waitSql.Contains([string]$connection.Host)) -Code "installation_observer_sql_secret_fixture_rejected"
  Clear-ChildPgEnvironment -StartInfo $info

  Assert-HardMonotonicDeadline -ElapsedMilliseconds 999 -TimeoutMilliseconds 1000 -FailureCode "fixture_timely_marker_rejected"
  Assert-LocalStableFailure -ExpectedCode "fixture_late_marker_rejected" -Operation {
    Assert-HardMonotonicDeadline -ElapsedMilliseconds 1001 -TimeoutMilliseconds 1000 -FailureCode "fixture_late_marker_rejected"
  }
  Assert-HardMonotonicDeadline -ElapsedMilliseconds 999 -TimeoutMilliseconds 1000 -FailureCode "fixture_stage_a_timely_marker_rejected"
  Assert-LocalStableFailure -ExpectedCode "fixture_stage_a_late_marker_rejected" -Operation {
    Assert-HardMonotonicDeadline -ElapsedMilliseconds 1001 -TimeoutMilliseconds 1000 -FailureCode "fixture_stage_a_late_marker_rejected"
  }
  Assert-HardMonotonicDeadline -ElapsedMilliseconds 1999 -TimeoutMilliseconds 2000 -FailureCode "fixture_stage_b_commit_timely_marker_rejected"
  Assert-LocalStableFailure -ExpectedCode "fixture_stage_b_commit_late_marker_rejected" -Operation {
    Assert-HardMonotonicDeadline -ElapsedMilliseconds 2001 -TimeoutMilliseconds 2000 -FailureCode "fixture_stage_b_commit_late_marker_rejected"
  }
  Assert-LocalStableFailure -ExpectedCode "fixture_matching_marker_late_rejected" -Operation {
    $matchingMarkerPresent = $true
    if ($matchingMarkerPresent) {
      Assert-HardMonotonicDeadline -ElapsedMilliseconds 1001 -TimeoutMilliseconds 1000 -FailureCode "fixture_matching_marker_late_rejected"
    }
  }
  $markerAbsentBeforeDeadline = $false
  if (-not $markerAbsentBeforeDeadline) {
    Assert-HardMonotonicDeadline -ElapsedMilliseconds 999 -TimeoutMilliseconds 1000 -FailureCode "fixture_absent_before_deadline_rejected"
  }
  Assert-LocalStableFailure -ExpectedCode "fixture_marker_present_after_deadline_rejected" -Operation {
    $markerPresentAfterDeadline = $true
    if ($markerPresentAfterDeadline) {
      Assert-HardMonotonicDeadline -ElapsedMilliseconds 1001 -TimeoutMilliseconds 1000 -FailureCode "fixture_marker_present_after_deadline_rejected"
    }
  }

  $validWaitMarker = ConvertFrom-InstallationWaitDirectionMarker -Lines @("INSTALLATION_WAIT_DIRECTION|1|750|1700000000000|1700000000750")
  Assert-Condition -Condition ($validWaitMarker.ServerWaitAgeMilliseconds -eq 750 -and $validWaitMarker.LockQueryStartEpochMilliseconds -eq 1700000000000 -and $validWaitMarker.ObservationEpochMilliseconds -eq 1700000000750) -Code "installation_wait_age_fixture_rejected"
  Assert-LocalStableFailure -ExpectedCode "installation_wait_direction_marker_rejected" -Operation {
    [void](ConvertFrom-InstallationWaitDirectionMarker -Lines @("NO_DIRECTION_MARKER|1"))
  }
  Assert-LocalStableFailure -ExpectedCode "installation_wait_direction_marker_rejected" -Operation {
    [void](ConvertFrom-InstallationWaitDirectionMarker -Lines @("INSTALLATION_WAIT_DIRECTION|1|750"))
  }
  Assert-LocalStableFailure -ExpectedCode "installation_wait_direction_marker_rejected" -Operation {
    [void](ConvertFrom-InstallationWaitDirectionMarker -Lines @("INSTALLATION_WAIT_DIRECTION|1|1|1700000000000|1700000000001", "INSTALLATION_WAIT_DIRECTION|1|2|1700000000000|1700000000002"))
  }
  Assert-LocalStableFailure -ExpectedCode "installation_wait_server_timestamp_rejected" -Operation {
    [void](ConvertFrom-InstallationWaitDirectionMarker -Lines @("INSTALLATION_WAIT_DIRECTION|1|-1|1700000000000|1699999999999"))
  }
  Assert-LocalStableFailure -ExpectedCode "installation_wait_age_rejected" -Operation {
    [void](ConvertFrom-InstallationWaitDirectionMarker -Lines @("INSTALLATION_WAIT_DIRECTION|1|2001|1700000000000|1700000002001"))
  }
  Assert-LocalStableFailure -ExpectedCode "installation_wait_direction_marker_rejected" -Operation {
    [void](ConvertFrom-InstallationWaitDirectionMarker -Lines @("INSTALLATION_WAIT_DIRECTION|1|1|not-a-timestamp|1700000000001"))
  }
  Assert-LocalStableFailure -ExpectedCode "installation_wait_server_clock_inconsistent" -Operation {
    [void](ConvertFrom-InstallationWaitDirectionMarker -Lines @("INSTALLATION_WAIT_DIRECTION|1|750|1700000000000|1700000000753"))
  }

  $validCommitMarker = ConvertFrom-InstallationHolderCommitMarker -Lines @("INSTALL_HOLDER_COMMITTED|1|1700000003999")
  Assert-Condition -Condition ($validCommitMarker.CommitMarkerEpochMilliseconds -eq 1700000003999) -Code "installation_holder_commit_fixture_rejected"
  Assert-LocalStableFailure -ExpectedCode "installation_holder_commit_marker_rejected" -Operation {
    [void](ConvertFrom-InstallationHolderCommitMarker -Lines @("INSTALL_HOLDER_COMMITTED|1"))
  }
  Assert-LocalStableFailure -ExpectedCode "installation_holder_commit_marker_rejected" -Operation {
    [void](ConvertFrom-InstallationHolderCommitMarker -Lines @("INSTALL_HOLDER_COMMITTED|1|-1"))
  }
  Assert-LocalStableFailure -ExpectedCode "installation_holder_commit_marker_rejected" -Operation {
    [void](ConvertFrom-InstallationHolderCommitMarker -Lines @("INSTALL_HOLDER_COMMITTED|1|1700000003999", "INSTALL_HOLDER_COMMITTED|1|1700000004000"))
  }

  $validObservation = [pscustomobject]@{
    WaitObserved = $true; ServerWaitAgeMilliseconds = 1000; LockQueryStartEpochMilliseconds = 1700000000000
    ObservationEpochMilliseconds = 1700000001000; ControllerObservationElapsedMilliseconds = 5000; CommandElapsedMilliseconds = 999
    MigrationActivitiesWaitUnGranted = $true; HolderLockGranted = $true
    AcademicPeriodsAccessExclusiveAbsent = $true; HolderAlive = $true; MigrationAlive = $true
  }
  Assert-Condition -Condition (Test-InstallationObservationAccepted -Observation $validObservation) -Code "installation_observation_positive_fixture_rejected"
  $pendingObservation = [pscustomobject]@{ WaitObserved = $false; ControllerObservationElapsedMilliseconds = 100 }
  Assert-Condition -Condition (Test-InstallationObservationSequenceAccepted -Samples @($pendingObservation, $validObservation)) -Code "installation_pending_then_true_fixture_rejected"
  $lateObservation = $validObservation.PSObject.Copy()
  $lateObservation.ControllerObservationElapsedMilliseconds = $script:InstallationWaitStartDeadlineMilliseconds
  Assert-Condition -Condition (-not (Test-InstallationObservationAccepted -Observation $lateObservation)) -Code "installation_late_true_fixture_rejected"
  $lateCommandObservation = $validObservation.PSObject.Copy()
  $lateCommandObservation.CommandElapsedMilliseconds = 1001
  Assert-Condition -Condition (-not (Test-InstallationObservationAccepted -Observation $lateCommandObservation)) -Code "installation_late_command_true_fixture_rejected"

  $server3999 = Get-ServerClockStructuralTiming -Observation $validObservation -CommitMarkerEpochMilliseconds 1700000003999
  Assert-Condition -Condition ($server3999.StructuralWaitThroughCommitMarkerMilliseconds -eq 3999 -and $server3999.WithinBudget) -Code "installation_server_structural_3999_fixture_rejected"
  $server4001 = Get-ServerClockStructuralTiming -Observation $validObservation -CommitMarkerEpochMilliseconds 1700000004001
  Assert-Condition -Condition ($server4001.StructuralWaitThroughCommitMarkerMilliseconds -eq 4001 -and -not $server4001.WithinBudget) -Code "installation_server_structural_4001_fixture_rejected"
  Assert-LocalStableFailure -ExpectedCode "installation_commit_server_clock_order_rejected" -Operation {
    [void](Get-ServerClockStructuralTiming -Observation $validObservation -CommitMarkerEpochMilliseconds 1700000000999)
  }
  $transportObservation = $validObservation.PSObject.Copy()
  $transportObservation.ServerWaitAgeMilliseconds = 1000
  $transportObservation.ObservationEpochMilliseconds = 1700000001000
  $serverIncludingTransport = Get-ServerClockStructuralTiming -Observation $transportObservation -CommitMarkerEpochMilliseconds 1700000001750
  $simulatedObserverResponseDelayMilliseconds = 750
  Assert-Condition -Condition ($serverIncludingTransport.StructuralWaitThroughCommitMarkerMilliseconds -eq 1750 -and $simulatedObserverResponseDelayMilliseconds -eq 750) -Code "installation_server_transport_interval_fixture_rejected"
  Assert-Condition -Condition ($validObservation.CommandElapsedMilliseconds -le $script:InstallationObserverCommandTimeoutMilliseconds -and $server3999.WithinBudget) -Code "installation_controller_server_budget_separation_fixture_rejected"
  Assert-Condition -Condition (Test-MigrationCompletionAccepted -LockAcquiredWithinBudget $true -TimedOut $false -ExitCode 0) -Code "installation_completion_positive_fixture_rejected"
  $migrationTotalElapsedMilliseconds = 9000
  Assert-Condition -Condition ($migrationTotalElapsedMilliseconds -gt $script:InstallationMigrationLockTimeoutMilliseconds -and (Test-MigrationCompletionAccepted -LockAcquiredWithinBudget $true -TimedOut $false -ExitCode 0)) -Code "installation_completion_after_lock_budget_fixture_rejected"
  Assert-Condition -Condition (-not (Test-MigrationCompletionAccepted -LockAcquiredWithinBudget $false -TimedOut $false -ExitCode 0)) -Code "installation_completion_lock_fixture_rejected"
  Assert-Condition -Condition (Test-TransactionMarkerOrdering -StageBSentMonotonicTimestamp 100 -PeriodReadObservedMonotonicTimestamp 101 -CommitObservedMonotonicTimestamp 102) -Code "installation_marker_order_positive_fixture_rejected"
  Assert-Condition -Condition (-not (Test-TransactionMarkerOrdering -StageBSentMonotonicTimestamp 100 -PeriodReadObservedMonotonicTimestamp 102 -CommitObservedMonotonicTimestamp 101)) -Code "installation_marker_order_negative_fixture_rejected"
  $migrationProcessExitedAtMonotonicTimestamp = 103
  $holderProcessExitedAtMonotonicTimestamp = 104
  Assert-Condition -Condition ($migrationProcessExitedAtMonotonicTimestamp -lt $holderProcessExitedAtMonotonicTimestamp -and (Test-TransactionMarkerOrdering -StageBSentMonotonicTimestamp 100 -PeriodReadObservedMonotonicTimestamp 101 -CommitObservedMonotonicTimestamp 102)) -Code "installation_process_exit_independence_fixture_rejected"
  $sanitized = "INSTALLATION_OBSERVER|APPROVED|SERVER_WAIT_AGE_WITHIN_LIMIT|1"
  Assert-Condition -Condition ($sanitized -notmatch '(?i)pid|query|epoch|fixture_secret|fixture\.invalid|[0-9a-f]{8}-[0-9a-f-]{27}') -Code "installation_observer_sanitized_evidence_rejected"
}

function Assert-SameProcessIsolationMarkerFixtures {
  $connection = [pscustomobject]@{
    Host = "fixture.invalid"; Port = "5432"; User = "fixture_user"; Password = "fixture_secret"
    Database = "fixture_database"; SslMode = "require"
  }
  $info = New-PsqlStartInfo -PsqlPath "psql.exe" -Connection $connection -SqlFile $script:MigrationPath -ApplicationName "sitaa_sem01_isolation_fixture" `
    -DefaultIsolation "repeatable read" -EmitSessionIsolationMarker -EmitRepositoryFileCompletedMarker
  $commandIndex = $info.Arguments.IndexOf(" -c ", [System.StringComparison]::Ordinal)
  $fileIndex = $info.Arguments.IndexOf(" -f ", [System.StringComparison]::Ordinal)
  $completedCommandIndex = $info.Arguments.IndexOf((Quote-ProcessArgument -Value $script:RepositoryFileCompletedMarkerSql), [System.StringComparison]::Ordinal)
  Assert-Condition -Condition ($commandIndex -ge 0 -and $fileIndex -gt $commandIndex -and $completedCommandIndex -gt $fileIndex) -Code "session_marker_argument_order_rejected" -FailureClass "source_integrity_rejection"
  Assert-Condition -Condition ($info.Arguments.Contains((Quote-ProcessArgument -Value $script:SessionIsolationMarkerSql))) -Code "session_marker_command_rejected" -FailureClass "source_integrity_rejection"
  Assert-Condition -Condition ($info.Arguments.Contains(" -f " + (Quote-ProcessArgument -Value $script:MigrationPath))) -Code "protected_repository_file_argument_rejected" -FailureClass "source_integrity_rejection"
  Assert-Condition -Condition ([string]$info.EnvironmentVariables["PGOPTIONS"] -match 'default_transaction_isolation=repeatable\\ read') -Code "same_process_repeatable_read_transport_rejected" -FailureClass "source_integrity_rejection"
  Assert-Condition -Condition (-not $info.Arguments.Contains([string]$connection.Password)) -Code "session_marker_fixture_credential_leak_rejected" -FailureClass "source_integrity_rejection"
  Clear-ChildPgEnvironment -StartInfo $info
  $validResult = [pscustomobject]@{ Stdout = "SESSION_DEFAULT_ISOLATION|repeatable read`n" }
  $parsedIsolation = Get-ExactSessionDefaultIsolation -Result $validResult
  Assert-Condition -Condition ($parsedIsolation -ceq "repeatable read") -Code "session_marker_fixture_rejected"
  $sanitizedEvidence = "SAME_PROCESS_DEFAULT_ISOLATION|" + [int]($parsedIsolation -ceq "repeatable read")
  Assert-Condition -Condition (-not $sanitizedEvidence.Contains([string]$connection.Password) -and -not $sanitizedEvidence.Contains($script:MigrationPath)) -Code "session_marker_sanitized_evidence_rejected" -FailureClass "source_integrity_rejection"
  Assert-Condition -Condition (Get-ExactRepositoryFileCompletedMarker -Result ([pscustomobject]@{ Stdout = "REPOSITORY_FILE_COMPLETED|1`n" })) -Code "repository_file_completed_fixture_rejected"
  Assert-LocalStableFailure -ExpectedCode "repository_file_completed_marker_rejected" -Operation {
    [void](Get-ExactRepositoryFileCompletedMarker -Result ([pscustomobject]@{ Stdout = "" }))
  }
  Assert-LocalStableFailure -ExpectedCode "session_default_isolation_marker_rejected" -Operation {
    [void](Get-ExactSessionDefaultIsolation -Result ([pscustomobject]@{ Stdout = "" }))
  }
  Assert-LocalStableFailure -ExpectedCode "session_default_isolation_marker_rejected" -Operation {
    [void](Get-ExactSessionDefaultIsolation -Result ([pscustomobject]@{ Stdout = "SESSION_DEFAULT_ISOLATION|repeatable read`nSESSION_DEFAULT_ISOLATION|repeatable read`n" }))
  }
  Assert-LocalStableFailure -ExpectedCode "session_default_isolation_value_rejected" -Operation {
    [void](Get-ExactSessionDefaultIsolation -Result ([pscustomobject]@{ Stdout = "SESSION_DEFAULT_ISOLATION|read committed`n" }))
  }
}

function Assert-WallClockTimingContract {
  $marginMilliseconds = $script:WallClockMarginSeconds * 1000
  $holderMilliseconds = $script:WallClockHolderSeconds * 1000
  Assert-Condition -Condition ($script:WallClockMarginSeconds -ge 45) -Code "wall_clock_margin_fixture_rejected"
  Assert-Condition -Condition ($script:WallClockHolderSeconds -ge ($script:WallClockMarginSeconds + 25)) -Code "wall_clock_holder_margin_fixture_rejected"
  Assert-Condition -Condition ($script:WallClockObserverTimeoutMilliseconds -gt $marginMilliseconds) -Code "wall_clock_observer_timeout_fixture_rejected"
  Assert-Condition -Condition ($holderMilliseconds -gt $script:WallClockObserverTimeoutMilliseconds) -Code "wall_clock_holder_timeout_fixture_rejected"
  Assert-Condition -Condition ($script:WallClockWorkerTimeoutMilliseconds -gt $holderMilliseconds) -Code "wall_clock_worker_timeout_fixture_rejected"
  Assert-Condition -Condition (($script:WallClockObserverTimeoutMilliseconds - $marginMilliseconds) -ge $script:WallClockSafetyIntervalMilliseconds) -Code "wall_clock_margin_safety_fixture_rejected"
  Assert-Condition -Condition (($holderMilliseconds - $script:WallClockObserverTimeoutMilliseconds) -ge $script:WallClockSafetyIntervalMilliseconds) -Code "wall_clock_holder_safety_fixture_rejected"
  Assert-Condition -Condition (($script:WallClockWorkerTimeoutMilliseconds - $holderMilliseconds) -ge $script:WallClockSafetyIntervalMilliseconds) -Code "wall_clock_worker_safety_fixture_rejected"
  Assert-Condition -Condition ($marginMilliseconds -gt 0 -and $script:WallClockObserverTimeoutMilliseconds -le 600000 -and $holderMilliseconds -le 600000 -and $script:WallClockWorkerTimeoutMilliseconds -le 600000) -Code "wall_clock_bounds_fixture_rejected"
}

function Invoke-Phase00Validate {
  param([switch]$AllowPreparationDelta)
  Assert-Condition -Condition ([System.IO.Path]::GetFullPath((Get-Location).Path) -eq $script:RepositoryRoot) -Code "repository_root_rejected"
  Assert-ScriptEncoding -Path $PSCommandPath
  Assert-PowerShellSyntax -Path $PSCommandPath
  Assert-ProtectedArtifacts
  Assert-No0012Artifacts
  Assert-RepositoryState -AllowPreparationDelta:$AllowPreparationDelta
  Assert-ExternalEvidenceRoot
  Assert-ScenarioContract
  Assert-SanitizerContract
  Assert-ManifestContractFixtures
  Assert-DiagnosticContractFixtures
  Assert-WorkerPidContractFixtures
  Assert-FrozenErrorRecordFixture
  Assert-PsqlProcessTimeoutContractFixtures
  Assert-PsqlWorkerOwnershipFixtures
  Assert-PgOptionsContractFixtures
  Assert-GenericObserverContractFixtures
  Assert-RuntimeObservationContractFixtures
  Assert-AdvisoryHolderReadinessFixtures
  Assert-Db21AdvisoryStagingAndOwnershipFixtures
  Assert-Db22TransientSqlCreationFixtures
  Assert-Db23PsqlHandoffFixtures
  Assert-Db24TransientSqlIdentityAndStarterEscrowFixtures
  Assert-Db25VerifiedArtifactAndProcessEscrowFixtures
  Assert-Db26WorkerHandoffAndMarkerDeadlineFixtures
  Assert-Db27RollbackRelationHolderFixtures
  Assert-Ms20CandidateSetContractFixtures
  Assert-InstallationLockBudgetFixtures
  Assert-StagedWorkerContractFixtures
  Assert-InstallationObserverContractFixtures
  Assert-SameProcessIsolationMarkerFixtures
  Assert-WallClockTimingContract
  Assert-TerminalArtifactContractFixtures
  Assert-SecondaryFailurePreservationFixtures
  Assert-OrchestrationCleanupContractFixtures
  Assert-CleanupStatePropagationFixtures
  Assert-StagedStartOwnershipFixtures
  Assert-FailureScenarioContractFixtures
  [void](Get-LabProjectReferenceFromCanonicalHarness)
  Assert-TargetBoundaryContract
  [void](Resolve-PsqlExecutable)
}

function Invoke-Phase01ReadOnlyBaseline {
  param(
    [Parameter(Mandatory = $true)][object]$Connection,
    [Parameter(Mandatory = $true)][string]$PsqlPath,
    [Parameter(Mandatory = $true)][object]$Paths,
    [Parameter(Mandatory = $true)][object]$Manifest,
    [Parameter(Mandatory = $true)][System.Collections.ArrayList]$ApprovedResults
  )
  Clear-CurrentScenario
  $baseline = Invoke-ReadOnlyBaseline -Connection $Connection -PsqlPath $PsqlPath -RunDirectory $Paths.Root -ExpectedState "POST0010"
  $Manifest.BaselineFingerprint = ConvertTo-FingerprintRecord -Fingerprint $baseline
  Set-ManifestPhase -Manifest $Manifest -Paths $Paths -Phase "PHASE_01_READ_ONLY_BASELINE" -ExpectedDatabaseState "POST0010" -ApprovedResults $ApprovedResults `
    -ExpectedDiagnosticCounts (Get-ExpectedDiagnosticCountsForPhase -Phase "PHASE_01_READ_ONLY_BASELINE") -ExpectedActivityFixture $null
}

function New-InstallationActivityFixtureSql {
  param(
    [Parameter(Mandatory = $true)][string]$AuthorityId,
    [Parameter(Mandatory = $true)][string]$ActivityId
  )
  return @"
begin;
select set_config('request.jwt.claim.sub', '$AuthorityId', true);
set local role authenticated;
insert into public.activities(
  id, title, description, academic_period_id, program_id,
  activity_type_code, service_type_code, attention_category_code,
  modality_code, status_code, location_type_code, location_detail,
  responsible_profile_id, created_by, start_date, start_time,
  end_date, end_time, duration_mode, scope_type, division_id
)
select
  '$ActivityId'::uuid, 'Fixture sintético multisesión 0011', null, null, program.id,
  (select code from public.activity_types where is_active order by code limit 1),
  (select code from public.service_types where is_active order by code limit 1),
  (select code from public.attention_categories where is_active order by code limit 1),
  (select code from public.activity_modalities where is_active order by code limit 1),
  'draft',
  (select code from public.location_types where is_active order by code limit 1),
  'Espacio sintético', '$AuthorityId'::uuid, '$AuthorityId'::uuid,
  date '2027-01-15', time '10:00', date '2027-01-15', time '11:00',
  'one_hour', 'program', program.division_id
from public.academic_programs program
where program.is_active
order by program.code
limit 1;
commit;
select 'FIXTURE_CREATED|1';
"@
}

function Remove-InstallationActivityFixture {
  param(
    [Parameter(Mandatory = $true)][object]$Connection,
    [Parameter(Mandatory = $true)][string]$PsqlPath,
    [Parameter(Mandatory = $true)][string]$RunDirectory,
    [Parameter(Mandatory = $true)][string]$AuthorityId,
    [Parameter(Mandatory = $true)][string]$ActivityId
  )
  $sql = @"
begin;
select set_config('request.jwt.claim.sub', '$AuthorityId', true);
set local role authenticated;
with removed as (
  delete from public.activities where id = '$ActivityId'::uuid and created_by = '$AuthorityId'::uuid returning id
)
select 'FIXTURE_REMOVED|' || count(*) from removed;
commit;
"@
  $result = Invoke-PsqlSql -Connection $Connection -PsqlPath $PsqlPath -Sql $sql -ApplicationName "sitaa_sem01_fixture_remove" -RunDirectory $RunDirectory -KeepRawLogs
  Assert-PsqlApproved -Result $result -FailureCode "installation_fixture_cleanup_failed"
  $parts = Get-MarkerParts -Result $result -Marker "FIXTURE_REMOVED"
  Assert-Condition -Condition ($parts.Count -eq 2 -and [int]$parts[1] -eq 1) -Code "installation_fixture_cleanup_rejected"
}

function Invoke-Phase02InstallationMatrix {
  param(
    [Parameter(Mandatory = $true)][object]$Connection,
    [Parameter(Mandatory = $true)][string]$PsqlPath,
    [Parameter(Mandatory = $true)][object]$Paths,
    [Parameter(Mandatory = $true)][object]$Manifest,
    [Parameter(Mandatory = $true)][System.Collections.ArrayList]$ApprovedResults,
    [Parameter(Mandatory = $true)][string]$AuthorityId
  )
  Clear-CurrentScenario
  $activityId = [guid]::NewGuid().ToString()
  $fixture = Invoke-PsqlSql -Connection $Connection -PsqlPath $PsqlPath -Sql (New-InstallationActivityFixtureSql -AuthorityId $AuthorityId -ActivityId $activityId) -ApplicationName "sitaa_sem01_fixture_create" -RunDirectory $Paths.Root -KeepRawLogs
  Assert-PsqlApproved -Result $fixture -FailureCode "installation_fixture_create_failed"
  Set-CurrentScenario -ScenarioId "MS01_PRE0011_ACTIVITY_RELATION_LOCK"

  $holder = $null
  $migration = $null
  $observer = $null
  $holderResult = $null
  $migrationResult = $null
  $observerResult = $null
  $phaseError = $null
  $phaseScenario = $null
  $phaseResults = New-Object System.Collections.ArrayList
  $phaseBoundaryReady = $false
  $expectedActivityFixture = $null
  try {
    $holder = Start-StagedInstallationHolder -Connection $Connection -PsqlPath $PsqlPath -RunDirectory $Paths.Root -AuthorityId $AuthorityId -ActivityId $activityId
    $fixedHolderDelayAbsent = (([string]$holder.StageA + "`n" + [string]$holder.StageB) -notmatch '(?i)pg_sleep\s*\(')
    Assert-Condition -Condition $fixedHolderDelayAbsent -Code "installation_fixed_holder_delay_rejected" -FailureClass "source_integrity_rejection"
    $stageARequest = Send-StagedInstallationHolderStage -Worker $holder -Stage "A"
    $updatedLiveMarker = Wait-StagedInstallationHolderMarker -Worker $holder -Marker "INSTALL_ACTIVITY_UPDATED" -StageRequest $stageARequest -TimeoutMilliseconds $script:InstallationWaitStartDeadlineMilliseconds

    $observer = Start-PersistentInstallationObserver -Connection $Connection -PsqlPath $PsqlPath -RunDirectory $Paths.Root
    $readyRequest = Send-PersistentInstallationObserverCommand -Observer $observer -Command "readiness"
    $readyResponse = Wait-PersistentInstallationObserverResponse -Observer $observer -Request $readyRequest
    Assert-Condition -Condition ($readyResponse.Line -ceq "INSTALLATION_OBSERVER_READY|1") -Code "installation_observer_readiness_rejected"
    $holderLockRequest = Send-PersistentInstallationObserverCommand -Observer $observer -Command "holder_lock"
    $holderLockResponse = Wait-PersistentInstallationObserverResponse -Observer $observer -Request $holderLockRequest
    Assert-Condition -Condition ($holderLockResponse.Line -ceq "INSTALLATION_HOLDER_LOCK|1" -and -not $holder.Process.HasExited) -Code "installation_holder_not_observed"
    $holderRelationLockObserved = $true

    $migration = Start-PsqlWorker -Connection $Connection -PsqlPath $PsqlPath -SqlFile $script:MigrationPath -ApplicationName "sitaa_sem01_install_migration" -RunDirectory $Paths.Root -DefaultIsolation "repeatable read" -StatementTimeoutMilliseconds 180000 -LockTimeoutMilliseconds 60000 -DeleteSqlFileOnCompletion $false -EmitSessionIsolationMarker -EmitRepositoryFileCompletedMarker

    Set-CurrentScenario -ScenarioId "MS02_MIGRATION_WAITS_FOR_ACTIVITIES_FIRST"
    $installationObservation = Wait-ForInstallationWaitDirection -Observer $observer -Holder $holder -Migration $migration
    Assert-Condition -Condition (Test-InstallationObservationAccepted -Observation $installationObservation) -Code "migration_wait_direction_not_observed"
    $stageBRequest = Send-StagedInstallationHolderStage -Worker $holder -Stage "B"
    Assert-Condition -Condition ($stageBRequest.SentMonotonicTimestamp -ge $installationObservation.ObservedMonotonicTimestamp) -Code "installation_stage_b_before_wait_observation_rejected" -FailureClass "source_integrity_rejection"
    $readLiveMarker = Wait-StagedInstallationHolderMarker -Worker $holder -Marker "INSTALL_PERIOD_READ" -StageRequest $stageBRequest -TimeoutMilliseconds $script:InstallationHolderCommitBudgetMilliseconds
    $commitLiveMarker = Wait-StagedInstallationHolderMarker -Worker $holder -Marker "INSTALL_HOLDER_COMMITTED" -StageRequest $stageBRequest -TimeoutMilliseconds $script:InstallationHolderCommitBudgetMilliseconds
    Assert-Condition -Condition ($commitLiveMarker.CommandElapsedMilliseconds -le $script:InstallationHolderCommitBudgetMilliseconds) -Code "installation_holder_commit_budget_rejected"
    $serverStructuralTiming = Get-ServerClockStructuralTiming -Observation $installationObservation -CommitMarkerEpochMilliseconds ([long]$commitLiveMarker.ServerEpochMilliseconds)
    Assert-Condition -Condition $serverStructuralTiming.WithinBudget -Code "installation_lock_budget_consumed"
    Assert-Condition -Condition (Test-TransactionMarkerOrdering -StageBSentMonotonicTimestamp $stageBRequest.SentMonotonicTimestamp `
      -PeriodReadObservedMonotonicTimestamp $readLiveMarker.ObservedMonotonicTimestamp -CommitObservedMonotonicTimestamp $commitLiveMarker.ObservedMonotonicTimestamp) -Code "installation_transaction_marker_order_rejected"

    $observerResult = Wait-PersistentInstallationObserver -Observer $observer -TimeoutMilliseconds $script:InstallationHolderProcessExitTimeoutMilliseconds -KeepRawLogs
    $observer = $null
    Assert-PsqlApproved -Result $observerResult -FailureCode "installation_observer_failed"
    $holderResult = Wait-StagedInstallationHolder -Worker $holder -TimeoutMilliseconds $script:InstallationHolderProcessExitTimeoutMilliseconds -KeepRawLogs
    $holder = $null
    Assert-PsqlApproved -Result $holderResult -FailureCode "installation_holder_failed"

    Set-CurrentScenario -ScenarioId "MS01_PRE0011_ACTIVITY_RELATION_LOCK"
    $ms01 = New-ScenarioResult -ScenarioId "MS01_PRE0011_ACTIVITY_RELATION_LOCK" -Outcome "activity_update_read_and_commit" -Assertions ([ordered]@{
      ActualUpdateCompleted = ($updatedLiveMarker.Value -ceq "1")
      StageACompletedWithinHardDeadline = ($updatedLiveMarker.CommandElapsedMilliseconds -le $script:InstallationWaitStartDeadlineMilliseconds)
      RelationLockObserved = $holderRelationLockObserved
      StageBSentAfterWaitDirection = ($stageBRequest.SentMonotonicTimestamp -ge $installationObservation.ObservedMonotonicTimestamp)
      AcademicPeriodsReadAfterWait = ($readLiveMarker.Value -ceq "1")
      HolderCommitted = ($commitLiveMarker.Value -ceq "1")
      StageBMarkersCompletedWithinHardDeadline = ($readLiveMarker.CommandElapsedMilliseconds -le $script:InstallationHolderCommitBudgetMilliseconds -and $commitLiveMarker.CommandElapsedMilliseconds -le $script:InstallationHolderCommitBudgetMilliseconds)
      HolderProcessExitedZero = ($holderResult.ExitCode -eq 0 -and -not $holderResult.TimedOut)
      NoFixedSleepUsedAsProof = $fixedHolderDelayAbsent
    })
    [void]$phaseResults.Add($ms01)

    Set-CurrentScenario -ScenarioId "MS02_MIGRATION_WAITS_FOR_ACTIVITIES_FIRST"
    $ms02 = New-ScenarioResult -ScenarioId "MS02_MIGRATION_WAITS_FOR_ACTIVITIES_FIRST" -Outcome "migration_waited_on_activities_before_period_lock" -Assertions ([ordered]@{
      MigrationActivitiesWaitObserved = $installationObservation.WaitObserved
      ExactShareRowExclusiveWaitObserved = $installationObservation.MigrationActivitiesWaitUnGranted
      HolderRowExclusiveStillGranted = $installationObservation.HolderLockGranted
      NoAcademicPeriodsAccessExclusiveRequested = $installationObservation.AcademicPeriodsAccessExclusiveAbsent
      HolderAcademicPeriodsReadCompleted = ($readLiveMarker.Value -ceq "1")
      WaitObservedWithinInstallationDeadline = ($installationObservation.ControllerObservationElapsedMilliseconds -lt $script:InstallationWaitStartDeadlineMilliseconds)
      ObserverCommandCompletedWithinHardDeadline = ($installationObservation.CommandElapsedMilliseconds -le $script:InstallationObserverCommandTimeoutMilliseconds)
      HolderAndMigrationAliveWhenObserved = ($installationObservation.HolderAlive -and $installationObservation.MigrationAlive)
      ServerWaitAgeWithinImmutableBudget = ($installationObservation.ServerWaitAgeMilliseconds -le $script:InstallationWaitAgeLimitMilliseconds)
      ServerClockTupleValid = (Test-InstallationServerClockTupleAccepted -ServerWaitAgeMilliseconds $installationObservation.ServerWaitAgeMilliseconds -LockQueryStartEpochMilliseconds $installationObservation.LockQueryStartEpochMilliseconds -ObservationEpochMilliseconds $installationObservation.ObservationEpochMilliseconds)
    })
    [void]$phaseResults.Add($ms02)

    Set-CurrentScenario -ScenarioId "MS03_ACTIVITY_COMMITS_BEFORE_MIGRATION_GUARD"
    $migrationResult = Wait-PsqlWorker -Worker $migration -TimeoutMilliseconds $script:InstallationMigrationCompletionTimeoutMilliseconds -KeepRawLogs
    $migration = $null
    Assert-PsqlApproved -Result $migrationResult -FailureCode "migration_installation_failed"
    $migrationText = $migrationResult.Stdout + "`n" + $migrationResult.Stderr
    Assert-Condition -Condition ($migrationText -notmatch '(?i)55P03|lock timeout') -Code "migration_installation_lock_timeout_rejected"
    $migrationDefaultIsolation = Get-ExactSessionDefaultIsolation -Result $migrationResult
    $repositoryFileCompleted = Get-ExactRepositoryFileCompletedMarker -Result $migrationResult
    $serverClockStructuralWaitThroughCommitWithinBudget = [bool]$serverStructuralTiming.WithinBudget
    Assert-Condition -Condition (Test-MigrationCompletionAccepted -LockAcquiredWithinBudget $serverClockStructuralWaitThroughCommitWithinBudget -TimedOut $migrationResult.TimedOut -ExitCode $migrationResult.ExitCode) -Code "migration_installation_completion_rejected"
    $postInstall = Invoke-ReadOnlyBaseline -Connection $Connection -PsqlPath $PsqlPath -RunDirectory $Paths.Root -ExpectedState "POST0011" -ExpectedActivityCount 1
    Assert-FingerprintPreserved -Observed $postInstall -Expected $Manifest.BaselineFingerprint
    $Manifest.Post0011Fingerprint = ConvertTo-FingerprintRecord -Fingerprint $postInstall
    $ms03 = New-ScenarioResult -ScenarioId "MS03_ACTIVITY_COMMITS_BEFORE_MIGRATION_GUARD" -Outcome "holder_committed_before_post_lock_guard" -Assertions ([ordered]@{
      HolderReadMarkerPresent = ($readLiveMarker.Value -ceq "1")
      HolderCommitMarkerPresent = ($commitLiveMarker.Value -ceq "1")
      TransactionMarkerOrderObserved = ($stageBRequest.SentMonotonicTimestamp -ge $installationObservation.ObservedMonotonicTimestamp -and (Test-TransactionMarkerOrdering -StageBSentMonotonicTimestamp $stageBRequest.SentMonotonicTimestamp -PeriodReadObservedMonotonicTimestamp $readLiveMarker.ObservedMonotonicTimestamp -CommitObservedMonotonicTimestamp $commitLiveMarker.ObservedMonotonicTimestamp))
      HolderCommitMarkerReceivedWithinControllerBudget = ($commitLiveMarker.CommandElapsedMilliseconds -le $script:InstallationHolderCommitBudgetMilliseconds)
      ServerClockStructuralWaitThroughCommitWithinBudget = $serverClockStructuralWaitThroughCommitWithinBudget
      MigrationCompletedWithinIndependentTimeout = (-not $migrationResult.TimedOut)
      MigrationExitCodeZero = ($migrationResult.ExitCode -eq 0)
      MigrationNo55P03 = ($migrationText -notmatch '(?i)55P03')
      MigrationNoLockTimeoutText = ($migrationText -notmatch '(?i)lock timeout')
      MigrationNo40P01 = ($migrationText -notmatch '(?i)40P01|deadlock detected')
      RepositoryFileCompletedMarkerPresent = $repositoryFileCompleted
      MigrationCommitObserved = ($migrationResult.ExitCode -eq 0 -and $postInstall.State -eq "POST0011")
      PostLockGuardAcceptedCommittedState = ($postInstall.State -eq "POST0011")
      ExactPost0011FingerprintCaptured = ($null -ne $Manifest.Post0011Fingerprint -and $Manifest.Post0011Fingerprint.BoundaryContractHash -ceq $postInstall.BoundaryContractHash)
      ExactlyOneInstallationActivity = ($postInstall.Activities -eq 1)
      ProtectedMigrationHashUnchanged = ((Get-Sha256 -Path $script:MigrationPath) -ceq $script:ExpectedHashes["supabase/migrations/0011_academic_period_administration.sql"])
    })
    [void]$phaseResults.Add($ms03)

    Set-CurrentScenario -ScenarioId "MS04_INSTALLATION_NO_DEADLOCK"
    $installationText = $holderResult.Stdout + $holderResult.Stderr + $migrationResult.Stdout + $migrationResult.Stderr + $observerResult.Stdout + $observerResult.Stderr
    $ms04 = New-ScenarioResult -ScenarioId "MS04_INSTALLATION_NO_DEADLOCK" -Outcome "zero_deadlocks" -Assertions ([ordered]@{
      HolderNo40P01 = ($installationText -notmatch '(?i)40P01')
      MigrationNoDeadlockText = ($installationText -notmatch '(?i)deadlock detected')
      ObserverNo40P01 = (($observerResult.Stdout + $observerResult.Stderr) -notmatch '(?i)40P01|deadlock detected')
      AllProcessesCompleted = ($holderResult.ExitCode -eq 0 -and $migrationResult.ExitCode -eq 0 -and $observerResult.ExitCode -eq 0)
      ZeroUnexpectedProcessTimeouts = (-not $holderResult.TimedOut -and -not $migrationResult.TimedOut -and -not $observerResult.TimedOut)
    })
    [void]$phaseResults.Add($ms04)

    Set-CurrentScenario -ScenarioId "MS05_MIGRATION_PINS_READ_COMMITTED"
    $migrationSource = [System.IO.File]::ReadAllText($script:MigrationPath, [System.Text.Encoding]::UTF8).Replace("`r`n", "`n").Replace("`r", "`n")
    $readCommittedIndex = $migrationSource.IndexOf("set transaction isolation level read committed;", [System.StringComparison]::Ordinal)
    $baselineGuardIndex = $migrationSource.IndexOf("do `$baseline_guard`$", [System.StringComparison]::Ordinal)
    $ms05 = New-ScenarioResult -ScenarioId "MS05_MIGRATION_PINS_READ_COMMITTED" -Outcome "repeatable_read_default_overridden" -Assertions ([ordered]@{
      SameProcessDefaultIsolationWasRepeatableRead = ($migrationDefaultIsolation -ceq "repeatable read")
      ExplicitReadCommittedPrecedesBaseline = ($readCommittedIndex -ge 0 -and $baselineGuardIndex -gt $readCommittedIndex)
      MigrationCompletedSuccessfully = ($migrationResult.ExitCode -eq 0)
      RepositoryFileCompletedInSameProcess = $repositoryFileCompleted
      MigrationCommitObserved = ($postInstall.State -eq "POST0011")
      ExactPost0011Postcondition = ($postInstall.State -eq "POST0011" -and $postInstall.Activities -eq 1)
    })
    [void]$phaseResults.Add($ms05)
    $activityFixture = Get-ActivityFixtureSnapshot -Connection $Connection -PsqlPath $PsqlPath -RunDirectory $Paths.Root -ActivityId $activityId
    Assert-Condition -Condition ($activityFixture.Activities -eq 1 -and $activityFixture.MatchingRows -eq 1 -and $activityFixture.RowFingerprint -cmatch '^[0-9a-f]{32}$') -Code "installation_activity_fixture_fingerprint_rejected"
    $expectedActivityFixture = [ordered]@{ Id = $activityId; RowFingerprint = $activityFixture.RowFingerprint }
    Assert-ProtectedArtifacts
    $phaseBoundaryReady = $true
  }
  catch {
    $phaseError = $_
    $phaseScenario = [string]$script:CurrentScenario
  }
  $phaseResources = [pscustomobject]@{ Holder = $holder; Migration = $migration; Observer = $observer }
  $phaseCleanup = Invoke-OrchestrationCleanup -EmitFailureMarkers -CleanupOperations @(
    [pscustomobject]@{ Name = "PHASE02_HOLDER_STAGE_B"; Operation = {
      if ($null -ne $phaseResources.Holder -and -not $phaseResources.Holder.Process.HasExited -and
        $phaseResources.Holder.StageState -ceq "stage_a_observed") {
        [void](Send-StagedInstallationHolderStage -Worker $phaseResources.Holder -Stage "B")
      }
    } },
    [pscustomobject]@{ Name = "PHASE02_HOLDER_COLLECT"; Operation = {
      if ($null -ne $phaseResources.Holder -and
        ($phaseResources.Holder.StageState -ceq "stage_b_sent" -or $phaseResources.Holder.Process.HasExited)) {
        [void](Wait-StagedInstallationHolder -Worker $phaseResources.Holder -TimeoutMilliseconds $script:InstallationHolderProcessExitTimeoutMilliseconds -KeepRawLogs)
        $phaseResources.Holder = $null
      }
    } },
    [pscustomobject]@{ Name = "PHASE02_HOLDER_STOP"; Operation = {
      if ($null -ne $phaseResources.Holder) {
        Stop-StagedInstallationHolder -Worker $phaseResources.Holder
        $phaseResources.Holder = $null
      }
    } },
    [pscustomobject]@{ Name = "PHASE02_MIGRATION_COLLECT"; Operation = {
      if ($null -ne $phaseResources.Migration) {
        [void](Wait-PsqlWorker -Worker $phaseResources.Migration -TimeoutMilliseconds 1000 -KeepRawLogs)
        $phaseResources.Migration = $null
      }
    } },
    [pscustomobject]@{ Name = "PHASE02_MIGRATION_STOP"; Operation = {
      if ($null -ne $phaseResources.Migration) {
        Stop-PsqlWorker -Worker $phaseResources.Migration
        $phaseResources.Migration = $null
      }
    } },
    [pscustomobject]@{ Name = "PHASE02_OBSERVER_COLLECT"; Operation = {
      if ($null -ne $phaseResources.Observer) {
        [void](Wait-PersistentInstallationObserver -Observer $phaseResources.Observer -TimeoutMilliseconds $script:InstallationHolderProcessExitTimeoutMilliseconds -KeepRawLogs)
        $phaseResources.Observer = $null
      }
    } },
    [pscustomobject]@{ Name = "PHASE02_OBSERVER_STOP"; Operation = {
      if ($null -ne $phaseResources.Observer) {
        Stop-PersistentInstallationObserver -Observer $phaseResources.Observer
        $phaseResources.Observer = $null
      }
    } }
  )
  Complete-OrchestrationCleanup -PrimaryError $phaseError -PrimaryScenario $phaseScenario -CleanupResult $phaseCleanup `
    -CleanupFailureCode "installation_orchestration_cleanup_rejected"
  Assert-Condition -Condition ($phaseBoundaryReady -and $phaseResults.Count -eq 5 -and $null -eq $phaseResources.Holder -and
    $null -eq $phaseResources.Migration -and $null -eq $phaseResources.Observer -and $null -ne $expectedActivityFixture) `
    -Code "installation_orchestration_cleanup_postcondition_rejected"
  foreach ($phaseResult in @($phaseResults)) {
    Approve-ScenarioResult -ApprovedResults $ApprovedResults -Manifest $Manifest -Paths $Paths -Result $phaseResult
  }
  $Manifest.InstallationFixtureId = $activityId
  Set-ManifestPhase -Manifest $Manifest -Paths $Paths -Phase "PHASE_02_INSTALLATION_MATRIX" -ExpectedDatabaseState "POST0011" -ApprovedResults $ApprovedResults `
    -ExpectedDiagnosticCounts (Get-ExpectedDiagnosticCountsForPhase -Phase "PHASE_02_INSTALLATION_MATRIX") -ExpectedActivityFixture $expectedActivityFixture
}

function Invoke-Phase03RollbackMatrix {
  param(
    [Parameter(Mandatory = $true)][object]$Connection,
    [Parameter(Mandatory = $true)][string]$PsqlPath,
    [Parameter(Mandatory = $true)][object]$Paths,
    [Parameter(Mandatory = $true)][object]$Manifest,
    [Parameter(Mandatory = $true)][System.Collections.ArrayList]$ApprovedResults,
    [Parameter(Mandatory = $true)][string]$AuthorityId
  )
  Clear-CurrentScenario
  Assert-Condition -Condition (-not [string]::IsNullOrWhiteSpace([string]$Manifest.InstallationFixtureId)) -Code "installation_fixture_manifest_missing"
  Remove-InstallationActivityFixture -Connection $Connection -PsqlPath $PsqlPath -RunDirectory $Paths.Root -AuthorityId $AuthorityId -ActivityId ([string]$Manifest.InstallationFixtureId)
  $eligibilitySql = @'
begin;
set transaction read only;
select 'ROLLBACK_ELIGIBLE|' || case
  when to_regclass('public.academic_period_audit_events') is not null
   and (select count(*) from public.academic_period_audit_events) = 0
   and (select count(*) from public.activities) = 0
  then 1 else 0 end;
rollback;
'@
  $eligibility = Invoke-PsqlSql -Connection $Connection -PsqlPath $PsqlPath -Sql $eligibilitySql -ApplicationName "sitaa_sem01_rollback_eligibility" -RunDirectory $Paths.Root
  Assert-PsqlApproved -Result $eligibility -FailureCode "rollback_eligibility_probe_failed"
  $parts = Get-MarkerParts -Result $eligibility -Marker "ROLLBACK_ELIGIBLE"
  Assert-Condition -Condition ($parts[1] -eq "1") -Code "rollback_eligibility_lost"
  Set-CurrentScenario -ScenarioId "MS06_ROLLBACK_PINS_READ_COMMITTED"

  $holderArtifact = New-SqlFile -RunDirectory $Paths.Root -Label "rollback_relation_holder" -InitialOwner controller `
    -Sql (Get-RollbackRelationHolderStageASql)
  $holderFile = $holderArtifact.Path
  $holderOwnershipState = $holderArtifact.OwnershipState
  $holder = $null
  $holderReadyMarker = $null
  $holderReadiness = $null
  $holderPostRejection = $null
  $holderReleaseMarker = $null
  $holderReleaseAbsence = $null
  $holderFinalAbsence = $null
  $holderResult = $null
  $holderBackendPid = 0
  $contended = $null
  $contendedDefaultIsolation = $null
  $contendedRollbackStartCount = 0
  $contendedAttemptRejected55P03 = $false
  $contendedAttemptHadNoDeadlock = $false
  $post0011FingerprintPreserved = $false
  $holderCleanupComplete = $false
  $rollbackError = $null
  $rollbackScenario = $null
  try {
    $holder = Start-StagedRollbackRelationHolder -Connection $Connection -PsqlPath $PsqlPath -RunDirectory $Paths.Root `
      -SqlFile $holderFile -DisposableSqlOwnershipState $holderOwnershipState
    $holderStageARequest = Send-StagedRollbackRelationHolderStage -Worker $holder -Stage "A"
    $holderReadyMarker = Wait-StagedRollbackRelationHolderMarker -Worker $holder -Marker "MS06_ROLLBACK_HOLDER_LOCKED" `
      -StageRequest $holderStageARequest -TimeoutMilliseconds $script:ObserverTimeoutMilliseconds
    Assert-Condition -Condition ($holderReadyMarker.Marker -ceq "MS06_ROLLBACK_HOLDER_LOCKED" -and
      $holderReadyMarker.CommandElapsedMilliseconds -le $script:ObserverTimeoutMilliseconds) `
      -Code "ms06_rollback_holder_ready_marker_deadline_rejected"
    $holderReadiness = Wait-ForExactRollbackRelationHolder -Connection $Connection -PsqlPath $PsqlPath -RunDirectory $Paths.Root `
      -HolderWorker $holder -ContendedRollbackStartCount $contendedRollbackStartCount
    $holderBackendPid = [int]$holderReadiness.Evidence.InternalHolderBackendPid
    Assert-Condition -Condition ($holderBackendPid -gt 0 -and $contendedRollbackStartCount -eq 0) `
      -Code "ms06_rollback_holder_frozen_identity_rejected"

    $contendedRollbackStartCount++
    Assert-Condition -Condition ($contendedRollbackStartCount -eq 1 -and $holderReadiness.Satisfied -and
      (Test-ExactRollbackRelationHolderEvidence -Evidence $holderReadiness.Evidence)) `
      -Code "ms06_contended_rollback_start_gate_rejected"
    $contended = Invoke-ExactRepositorySqlFileResult -Connection $Connection -PsqlPath $PsqlPath -RepositorySqlFile $script:RollbackPath -ApplicationName "sitaa_sem01_rollback_contended" -RunDirectory $Paths.Root -DefaultIsolation "repeatable read" -LockTimeoutMilliseconds 15000
    $contendedDefaultIsolation = Get-ExactSessionDefaultIsolation -Result $contended
    if ($contended.ExitCode -eq 0 -and -not $contended.TimedOut) {
      $unexpectedContendedPhaseDiagnostic = Invoke-SecondaryFailureOperation -Operation {
        Get-DatabasePhase -Connection $Connection -PsqlPath $PsqlPath -RunDirectory $Paths.Root
      }
      $unexpectedContendedPhase = if ($unexpectedContendedPhaseDiagnostic.Succeeded) {
        [string]$unexpectedContendedPhaseDiagnostic.Value
      }
      else { "UNKNOWN" }
      Assert-Condition -Condition ($unexpectedContendedPhase -in @("POST0010", "POST0011", "UNKNOWN")) `
        -Code "rollback_contended_attempt_diagnostic_phase_rejected" -FailureClass "postcondition_rejection"
      Throw-StableFailure -Code "rollback_contended_attempt_unexpected_success" -FailureClass "postcondition_rejection"
    }
    Assert-Condition -Condition (-not $contended.TimedOut) -Code "rollback_contended_attempt_unexpected_timeout" -FailureClass "unexpected_timeout"
    $contendedOutput = $contended.Stderr + "`n" + $contended.Stdout
    $contendedAttemptHadNoDeadlock = -not ($contendedOutput -match '(?i)40P01|deadlock detected')
    Assert-Condition -Condition $contendedAttemptHadNoDeadlock -Code "postgres_deadlock_40P01" -FailureClass "postgres_deadlock"
    Assert-ExpectedSqlState -Result $contended -SqlState "55P03" -MessagePattern "could not obtain lock|lock not available" -FailureCode "rollback_nowait_contract_rejected"
    $contendedAttemptRejected55P03 = $true
    $stillApplied = Invoke-ReadOnlyFingerprint -Connection $Connection -PsqlPath $PsqlPath -RunDirectory $Paths.Root -ExpectedState "POST0011"
    Assert-Condition -Condition ($stillApplied.State -eq "POST0011" -and $stillApplied.Activities -eq 0 -and $stillApplied.AuditEvents -eq 0) -Code "contended_rollback_changed_database"
    Assert-FingerprintPreserved -Observed $stillApplied -Expected $Manifest.Post0011Fingerprint -IncludeResolver -IncludeBoundaryContract
    $post0011FingerprintPreserved = $true
    $holderPostRejection = Wait-ForExactRollbackRelationHolder -Connection $Connection -PsqlPath $PsqlPath -RunDirectory $Paths.Root `
      -HolderWorker $holder -ContendedRollbackStartCount $contendedRollbackStartCount -ExpectedBackendPid $holderBackendPid
    Assert-Condition -Condition ($holderPostRejection.Satisfied -and
      $holderPostRejection.Evidence.InternalHolderBackendPid -eq $holderBackendPid -and
      $holderPostRejection.Evidence.ExactRelationLockCount -eq 1) -Code "ms06_same_holder_post_rejection_rejected"

    $holderStageBRequest = Send-StagedRollbackRelationHolderStage -Worker $holder -Stage "B" `
      -Exact55P03Observed $contendedAttemptRejected55P03 `
      -PostRejectionHolderObserved $holderPostRejection.Satisfied `
      -Post0011FingerprintPreserved $post0011FingerprintPreserved
    $holderReleaseMarker = Wait-StagedRollbackRelationHolderMarker -Worker $holder -Marker "MS06_ROLLBACK_HOLDER_RELEASED" `
      -StageRequest $holderStageBRequest -TimeoutMilliseconds $script:ObserverTimeoutMilliseconds
    Assert-Condition -Condition ($holderReleaseMarker.Marker -ceq "MS06_ROLLBACK_HOLDER_RELEASED" -and
      $holderReleaseMarker.CommandElapsedMilliseconds -le $script:ObserverTimeoutMilliseconds) `
      -Code "ms06_rollback_holder_release_marker_deadline_rejected"
    $holderReleaseAbsence = Wait-ForRollbackRelationHolderAbsence -Connection $Connection -PsqlPath $PsqlPath `
      -RunDirectory $Paths.Root -ExpectedBackendPid $holderBackendPid -RequireSessionAbsent $false
    $holderResult = Wait-StagedRollbackRelationHolder -Worker $holder -TimeoutMilliseconds 30000 -KeepRawLogs
    $holder = $null
    Assert-PsqlApproved -Result $holderResult -FailureCode "rollback_holder_failed"
    $holderFinalAbsence = Wait-ForRollbackRelationHolderAbsence -Connection $Connection -PsqlPath $PsqlPath `
      -RunDirectory $Paths.Root -ExpectedBackendPid $holderBackendPid -RequireSessionAbsent $true
    $holderCleanupComplete = ($holderReleaseAbsence.Satisfied -and $holderFinalAbsence.Satisfied -and
      [string]$holderOwnershipState.OwnerState -ceq "completed" -and
      -not (Test-Path -LiteralPath $holderFile) -and
      (Get-TransientWorkerSqlFileCount -RunDirectory $Paths.Root) -eq 0 -and
      @(Get-WorkerPidManifestValues -RunDirectory $Paths.Root).Count -eq 0 -and
      @($Manifest.ActiveWorkerPids).Count -eq 0)
    Assert-Condition -Condition $holderCleanupComplete -Code "ms06_rollback_holder_cleanup_incomplete" -FailureClass "postcondition_rejection"
  }
  catch {
    $rollbackError = $_
    $rollbackScenario = [string]$script:CurrentScenario
  }
  $rollbackResources = [pscustomobject]@{ Holder = $holder; ContendedResult = $contended }
  $rollbackCleanup = Invoke-OrchestrationCleanup -EmitFailureMarkers -CleanupOperations @(
    [pscustomobject]@{ Name = "PHASE03_CONTENDED_WORKER_COLLECTION"; Operation = {
      if ($null -ne $rollbackResources.ContendedResult) {
        Assert-Condition -Condition (-not $rollbackResources.ContendedResult.TimedOut) `
          -Code "rollback_contended_worker_collection_rejected" -FailureClass "postcondition_rejection"
      }
    } },
    [pscustomobject]@{ Name = "PHASE03_HOLDER_STOP"; Operation = {
      if ($null -ne $rollbackResources.Holder) {
        Stop-StagedRollbackRelationHolder -Worker $rollbackResources.Holder
        $rollbackResources.Holder = $null
      }
    } },
    [pscustomobject]@{ Name = "PHASE03_HOLDER_SQL_REMOVE"; Operation = {
      if ([string]$holderOwnershipState.OwnerState -cin @("caller", "controller")) {
        $holderSqlCleanup = Invoke-PsqlDisposableControllerCleanup -State $holderOwnershipState
        Assert-Condition -Condition $holderSqlCleanup.Succeeded -Code "rollback_holder_sql_cleanup_rejected"
      }
      elseif ([string]$holderOwnershipState.OwnerState -cin @("starter", "worker")) {
        Assert-Condition -Condition $false -Code "rollback_holder_cleanup_ownership_incomplete" -FailureClass "postcondition_rejection"
      }
    } }
  )
  Complete-OrchestrationCleanup -PrimaryError $rollbackError -PrimaryScenario $rollbackScenario -CleanupResult $rollbackCleanup `
    -CleanupFailureCode "rollback_holder_cleanup_rejected"

  Assert-Condition -Condition $holderCleanupComplete -Code "successful_rollback_before_holder_cleanup_rejected" -FailureClass "postcondition_rejection"
  $successfulRollback = Invoke-ExactRepositorySqlFile -Connection $Connection -PsqlPath $PsqlPath -RepositorySqlFile $script:RollbackPath -ApplicationName "sitaa_sem01_rollback_exact" -RunDirectory $Paths.Root -DefaultIsolation "repeatable read"
  $successfulRollbackDefaultIsolation = Get-ExactSessionDefaultIsolation -Result $successfulRollback
  Assert-Condition -Condition ((Get-DatabasePhase -Connection $Connection -PsqlPath $PsqlPath -RunDirectory $Paths.Root) -eq "POST0010") -Code "rollback_postcondition_rejected"
  $postRollback = Invoke-ReadOnlyBaseline -Connection $Connection -PsqlPath $PsqlPath -RunDirectory $Paths.Root -ExpectedState "POST0010"
  Assert-FingerprintPreserved -Observed $postRollback -Expected $Manifest.BaselineFingerprint -IncludeResolver -IncludeBoundaryContract
  $rollbackSource = [System.IO.File]::ReadAllText($script:RollbackPath, [System.Text.Encoding]::UTF8).Replace("`r`n", "`n").Replace("`r", "`n")
  $rollbackReadCommittedIndex = $rollbackSource.IndexOf("set transaction isolation level read committed;", [System.StringComparison]::Ordinal)
  $rollbackEligibilityIndex = $rollbackSource.IndexOf("do `$rollback_shape_guard`$", [System.StringComparison]::Ordinal)
  $zeroWorkerLockAndSqlResidue = ($postRollback.OpenWorkers -eq 0 -and $postRollback.TransientWorkerSqlFiles -eq 0 -and
    $holderFinalAbsence.Satisfied -and @(Get-WorkerPidManifestValues -RunDirectory $Paths.Root).Count -eq 0 -and
    @($Manifest.ActiveWorkerPids).Count -eq 0)
  $ms06 = New-ScenarioResult -ScenarioId "MS06_ROLLBACK_PINS_READ_COMMITTED" -Outcome "contended_55P03_then_repeatable_read_success" -Assertions ([ordered]@{
    EligibilityConfirmed = ($parts[1] -eq "1")
    HolderStageAObserved = ($holderReadyMarker.Marker -ceq "MS06_ROLLBACK_HOLDER_LOCKED")
    HolderStageAWithinDeadline = ($holderReadyMarker.CommandElapsedMilliseconds -le $script:ObserverTimeoutMilliseconds)
    ExactHolderSessionObserved = ($holderReadiness.Evidence.ExactHolderCount -eq 1 -and $holderReadiness.Evidence.ExactBackendType -and $holderReadiness.Evidence.IdleInTransaction)
    ExactHolderRelationLockObserved = ($holderReadiness.Evidence.ExactRelationLockCount -eq 1)
    ContendedRollbackStartedAfterHolderReady = ($contendedRollbackStartCount -eq 1 -and $holderReadiness.Satisfied)
    ContendedSameProcessDefaultIsolationWasRepeatableRead = ($contendedDefaultIsolation -ceq "repeatable read")
    ContendedAttemptRejected55P03 = $contendedAttemptRejected55P03
    ContendedAttemptHadNoDeadlock = $contendedAttemptHadNoDeadlock
    SameHolderStillLockedAfterRejection = ($holderPostRejection.Satisfied -and $holderPostRejection.Evidence.InternalHolderBackendPid -eq $holderBackendPid -and $holderPostRejection.Evidence.ExactRelationLockCount -eq 1)
    ContendedAttemptLeftPost0011 = ($stillApplied.State -eq "POST0011")
    HolderReleasedOnlyAfter55P03 = ($contendedAttemptRejected55P03 -and $holderPostRejection.Satisfied -and $post0011FingerprintPreserved -and $null -ne $holderStageBRequest)
    HolderReleaseMarkerObserved = ($holderReleaseMarker.Marker -ceq "MS06_ROLLBACK_HOLDER_RELEASED")
    HolderReleaseMarkerWithinDeadline = ($holderReleaseMarker.CommandElapsedMilliseconds -le $script:ObserverTimeoutMilliseconds)
    HolderProcessCollected = ($holderResult.ExitCode -eq 0 -and -not $holderResult.TimedOut)
    HolderTransientSqlRemoved = (-not (Test-Path -LiteralPath $holderFile) -and [string]$holderOwnershipState.OwnerState -ceq "completed")
    SuccessfulSameProcessDefaultIsolationWasRepeatableRead = ($successfulRollbackDefaultIsolation -ceq "repeatable read")
    ExplicitReadCommittedPrecedesEligibilityReads = ($rollbackReadCommittedIndex -ge 0 -and $rollbackEligibilityIndex -gt $rollbackReadCommittedIndex)
    SecondAttemptCompleted = ($postRollback.State -eq "POST0010")
    SuccessfulRollbackCommitObserved = ($successfulRollback.ExitCode -eq 0 -and $postRollback.State -eq "POST0010")
    ReadCommittedPinRestoredPost0010 = ($postRollback.ResolverHash -eq $Manifest.BaselineFingerprint.ResolverHash)
    ZeroWorkerLockAndSqlResidue = $zeroWorkerLockAndSqlResidue
  })
  Approve-ScenarioResult -ApprovedResults $ApprovedResults -Manifest $Manifest -Paths $Paths -Result $ms06
  $Manifest.InstallationFixtureId = $null
  $Manifest.ExpectedActivityFixture = $null
  Assert-ProtectedArtifacts
  Set-ManifestPhase -Manifest $Manifest -Paths $Paths -Phase "PHASE_03_ROLLBACK_MATRIX" -ExpectedDatabaseState "POST0010" -ApprovedResults $ApprovedResults `
    -ExpectedDiagnosticCounts (Get-ExpectedDiagnosticCountsForPhase -Phase "PHASE_03_ROLLBACK_MATRIX") -ExpectedActivityFixture $null
}

function Invoke-Phase04Reapply0011 {
  param(
    [Parameter(Mandatory = $true)][object]$Connection,
    [Parameter(Mandatory = $true)][string]$PsqlPath,
    [Parameter(Mandatory = $true)][object]$Paths,
    [Parameter(Mandatory = $true)][object]$Manifest,
    [Parameter(Mandatory = $true)][System.Collections.ArrayList]$ApprovedResults
  )
  Clear-CurrentScenario
  [void](Invoke-ExactRepositorySqlFile -Connection $Connection -PsqlPath $PsqlPath -RepositorySqlFile $script:MigrationPath -ApplicationName "sitaa_sem01_reapply_exact" -RunDirectory $Paths.Root)
  $postReapply = Invoke-ReadOnlyBaseline -Connection $Connection -PsqlPath $PsqlPath -RunDirectory $Paths.Root -ExpectedState "POST0011"
  Assert-FingerprintPreserved -Observed $postReapply -Expected $Manifest.BaselineFingerprint
  Assert-FingerprintPreserved -Observed $postReapply -Expected $Manifest.Post0011Fingerprint -IncludeResolver -IncludeBoundaryContract
  $Manifest.Post0011Fingerprint = ConvertTo-FingerprintRecord -Fingerprint $postReapply
  Assert-ProtectedArtifacts
  Set-ManifestPhase -Manifest $Manifest -Paths $Paths -Phase "PHASE_04_REAPPLY_0011" -ExpectedDatabaseState "POST0011" -ApprovedResults $ApprovedResults `
    -ExpectedDiagnosticCounts (Get-ExpectedDiagnosticCountsForPhase -Phase "PHASE_04_REAPPLY_0011") -ExpectedActivityFixture $null
}

function New-RuntimeActivityFixture {
  param(
    [Parameter(Mandatory = $true)][object]$Connection,
    [Parameter(Mandatory = $true)][string]$PsqlPath,
    [Parameter(Mandatory = $true)][string]$RunDirectory,
    [Parameter(Mandatory = $true)][string]$AuthorityId,
    [Parameter(Mandatory = $true)][string]$ActivityId,
    [int]$FutureSeconds = 0
  )
  $scheduleExpression = if ($FutureSeconds -gt 0) {
    "(clock_timestamp() at time zone 'America/Mexico_City') + interval '$FutureSeconds seconds'"
  }
  else {
    "greatest((clock_timestamp() at time zone 'America/Mexico_City') + interval '7 days', period.starts_on::timestamp + interval '10 hours')"
  }
  $coveragePredicate = if ($FutureSeconds -gt 0) {
    "(clock_timestamp() at time zone 'America/Mexico_City')::date between p.starts_on and p.ends_on"
  }
  else {
    "p.ends_on >= (clock_timestamp() at time zone 'America/Mexico_City')::date + 9"
  }
  $sql = @"
begin;
select set_config('request.jwt.claim.sub', '$AuthorityId', true);
set local role authenticated;
with period as (
  select p.* from public.academic_periods p
  where p.is_active and p.code <> 'pilot' and p.starts_on is not null and p.ends_on is not null
    and $coveragePredicate
  order by p.starts_on limit 1
), schedule as (
  select $scheduleExpression as starts_local from period
), inserted as (
  insert into public.activities(
    id, title, description, academic_period_id, program_id, activity_type_code,
    service_type_code, attention_category_code, modality_code, status_code,
    location_type_code, location_detail, responsible_profile_id, created_by,
    start_date, start_time, end_date, end_time, duration_mode, scope_type, division_id
  )
  select '$ActivityId'::uuid, 'Fixture sintético multisesión 0011', 'Uso exclusivo LAB', null,
    program.id,
    (select code from public.activity_types where is_active order by code limit 1),
    (select code from public.service_types where is_active order by code limit 1),
    (select code from public.attention_categories where is_active order by code limit 1),
    (select code from public.activity_modalities where is_active and code <> 'online' order by code limit 1),
    'draft',
    (select code from public.location_types where is_active and code <> 'online_space' order by code limit 1),
    'Espacio sintético', '$AuthorityId'::uuid, '$AuthorityId'::uuid,
    schedule.starts_local::date, schedule.starts_local::time,
    (schedule.starts_local + interval '1 hour')::date,
    (schedule.starts_local + interval '1 hour')::time,
    'one_hour', 'program', program.division_id
  from period join schedule on true
  cross join lateral (select * from public.academic_programs where is_active order by code limit 1) program
  where schedule.starts_local::date between period.starts_on and period.ends_on
  returning id
)
select 'RUNTIME_FIXTURE_CREATED|' || count(*) from inserted;
commit;
"@
  $result = Invoke-PsqlSql -Connection $Connection -PsqlPath $PsqlPath -Sql $sql -ApplicationName "sitaa_sem01_runtime_fixture" -RunDirectory $RunDirectory -KeepRawLogs
  Assert-PsqlApproved -Result $result -FailureCode "runtime_activity_fixture_rejected"
  $marker = Get-MarkerParts -Result $result -Marker "RUNTIME_FIXTURE_CREATED"
  Assert-Condition -Condition ($marker[1] -eq "1") -Code "runtime_activity_fixture_missing"
}

function Remove-RuntimeActivityFixture {
  param(
    [Parameter(Mandatory = $true)][object]$Connection,
    [Parameter(Mandatory = $true)][string]$PsqlPath,
    [Parameter(Mandatory = $true)][string]$RunDirectory,
    [Parameter(Mandatory = $true)][string]$ActivityId,
    [Parameter(Mandatory = $true)][string]$Label
  )
  $sql = @"
begin;
with removed as (
  delete from public.activities
  where id = '$ActivityId'::uuid and title = 'Fixture sintético multisesión 0011'
  returning id
)
select 'RUNTIME_FIXTURE_REMOVED|' || count(*) from removed;
commit;
"@
  $result = Invoke-PsqlSql -Connection $Connection -PsqlPath $PsqlPath -Sql $sql -ApplicationName ("sitaa_sem01_" + $Label) -RunDirectory $RunDirectory -KeepRawLogs
  Assert-PsqlApproved -Result $result -FailureCode "runtime_activity_cleanup_failed"
  $marker = Get-MarkerParts -Result $result -Marker "RUNTIME_FIXTURE_REMOVED"
  Assert-Condition -Condition ($marker[1] -eq "1") -Code "runtime_activity_cleanup_count_rejected"
}

function Get-RuntimeActivityFixturePresence {
  param(
    [Parameter(Mandatory = $true)][object]$Connection,
    [Parameter(Mandatory = $true)][string]$PsqlPath,
    [Parameter(Mandatory = $true)][string]$RunDirectory,
    [Parameter(Mandatory = $true)][string]$ActivityId,
    [Parameter(Mandatory = $true)][string]$Label
  )
  $sql = "begin; set transaction read only; select 'RUNTIME_FIXTURE_EXISTS|' || count(*) from public.activities where id = '$ActivityId'::uuid and title = 'Fixture sintético multisesión 0011'; rollback;"
  $result = Invoke-PsqlSql -Connection $Connection -PsqlPath $PsqlPath -Sql $sql -ApplicationName ("sitaa_sem01_" + $Label) -RunDirectory $RunDirectory
  Assert-PsqlApproved -Result $result -FailureCode "runtime_activity_presence_probe_rejected"
  $marker = Get-MarkerParts -Result $result -Marker "RUNTIME_FIXTURE_EXISTS"
  Assert-Condition -Condition ($marker.Count -eq 2 -and [int]$marker[1] -in @(0, 1)) -Code "runtime_activity_presence_marker_rejected"
  return [pscustomobject]@{ Exists = ([int]$marker[1] -eq 1) }
}

function Assert-RuntimeActivityFixtureAbsent {
  param(
    [Parameter(Mandatory = $true)][object]$Connection,
    [Parameter(Mandatory = $true)][string]$PsqlPath,
    [Parameter(Mandatory = $true)][string]$RunDirectory,
    [Parameter(Mandatory = $true)][string]$ActivityId,
    [Parameter(Mandatory = $true)][string]$Label
  )
  $presence = Get-RuntimeActivityFixturePresence -Connection $Connection -PsqlPath $PsqlPath -RunDirectory $RunDirectory `
    -ActivityId $ActivityId -Label $Label
  Assert-Condition -Condition (-not $presence.Exists) -Code "runtime_activity_cleanup_residue"
}

function Invoke-MutationFingerprint {
  param(
    [Parameter(Mandatory = $true)][object]$Connection,
    [Parameter(Mandatory = $true)][string]$PsqlPath,
    [Parameter(Mandatory = $true)][string]$RunDirectory,
    [Parameter(Mandatory = $true)][string]$Label
  )
  $sql = @'
begin;
set transaction read only;
select 'MUTATION_FINGERPRINT|' ||
  coalesce((select md5(string_agg(to_jsonb(p)::text, E'\n' order by p.id)) from public.academic_periods p), md5('')) || '|' ||
  coalesce((select md5(string_agg(to_jsonb(a)::text, E'\n' order by a.id)) from public.activities a), md5('')) || '|' ||
  coalesce((select md5(string_agg(to_jsonb(e)::text, E'\n' order by e.id)) from public.academic_period_audit_events e), md5(''));
rollback;
'@
  $result = Invoke-PsqlSql -Connection $Connection -PsqlPath $PsqlPath -Sql $sql -ApplicationName ("sitaa_sem01_" + $Label) -RunDirectory $RunDirectory
  Assert-PsqlApproved -Result $result -FailureCode "mutation_fingerprint_failed"
  $parts = Get-MarkerParts -Result $result -Marker "MUTATION_FINGERPRINT"
  Assert-Condition -Condition ($parts.Count -eq 4) -Code "mutation_fingerprint_shape_rejected"
  return ($parts[1..3] -join '|')
}

function Assert-NoRuntimeResidue {
  param(
    [Parameter(Mandatory = $true)][object]$Connection,
    [Parameter(Mandatory = $true)][string]$PsqlPath,
    [Parameter(Mandatory = $true)][string]$RunDirectory,
    [Parameter(Mandatory = $true)][int]$ExpectedActivities
  )
  $fingerprint = Invoke-ReadOnlyBaseline -Connection $Connection -PsqlPath $PsqlPath -RunDirectory $RunDirectory -ExpectedState "POST0011" -ExpectedActivityCount $ExpectedActivities
  return $fingerprint
}

function Invoke-IsolationScenarios {
  param(
    [Parameter(Mandatory = $true)][object]$Connection,
    [Parameter(Mandatory = $true)][string]$PsqlPath,
    [Parameter(Mandatory = $true)][object]$Paths,
    [Parameter(Mandatory = $true)][object]$Manifest,
    [Parameter(Mandatory = $true)][System.Collections.ArrayList]$ApprovedResults,
    [Parameter(Mandatory = $true)][string]$AuthorityId,
    [Parameter(Mandatory = $true)][string]$ActivityId
  )
  $before = Invoke-MutationFingerprint -Connection $Connection -PsqlPath $PsqlPath -RunDirectory $Paths.Root -Label "isolation_before"

  Set-CurrentScenario -ScenarioId "MS07_ADMIN_RPC_REJECTS_HIGH_ISOLATION"
  $adminSql = New-Object System.Collections.ArrayList
  foreach ($level in @("repeatable read", "serializable")) {
    [void]$adminSql.Add(@"
begin isolation level $level;
select set_config('request.jwt.claim.sub', '$AuthorityId', true);
set local role authenticated;
do `$ms07`$ begin
  begin
    perform * from public.create_admin_academic_period('2098-1', date '2098-02-01', date '2098-05-31', true);
    raise exception 'ms07_unexpected_success';
  exception when sqlstate '25000' then
    if sqlerrm <> 'sitaa_sem01_read_committed_required' then raise; end if;
  end;
end; `$ms07`$;
select 'MS07_GUARD|$level|25000';
rollback;
"@)
  }
  $adminResult = Invoke-PsqlSql -Connection $Connection -PsqlPath $PsqlPath -Sql ($adminSql -join "`n") -ApplicationName "sitaa_sem01_ms07_isolation" -RunDirectory $Paths.Root -KeepRawLogs
  Assert-PsqlApproved -Result $adminResult -FailureCode "ms07_isolation_contract_rejected"
  $ms07Markers = @($adminResult.Stdout -split "\r?\n" | Where-Object { $_.StartsWith("MS07_GUARD|") })
  $after07 = Invoke-MutationFingerprint -Connection $Connection -PsqlPath $PsqlPath -RunDirectory $Paths.Root -Label "isolation_after07"
  $ms07 = New-ScenarioResult -ScenarioId "MS07_ADMIN_RPC_REJECTS_HIGH_ISOLATION" -Outcome "25000_before_admin_mutation" -Assertions ([ordered]@{
    BothIsolationLevelsRejected = ($ms07Markers.Count -eq 2)
    ExactContractObserved = (($ms07Markers -join "`n") -match 'repeatable read\|25000' -and ($ms07Markers -join "`n") -match 'serializable\|25000')
    ZeroMutation = ($after07 -ceq $before)
  })
  Approve-ScenarioResult -ApprovedResults $ApprovedResults -Manifest $Manifest -Paths $Paths -Result $ms07

  Set-CurrentScenario -ScenarioId "MS08_PUBLISH_REJECTS_HIGH_ISOLATION"
  $publishSql = New-Object System.Collections.ArrayList
  foreach ($level in @("repeatable read", "serializable")) {
    [void]$publishSql.Add(@"
begin isolation level $level;
select set_config('request.jwt.claim.sub', '$AuthorityId', true);
set local role authenticated;
do `$ms08`$ begin
  begin
    perform * from public.publish_activity('$ActivityId'::uuid);
    raise exception 'ms08_unexpected_success';
  exception when sqlstate '25000' then
    if sqlerrm <> 'sitaa_sem01_read_committed_required' then raise; end if;
  end;
end; `$ms08`$;
select 'MS08_GUARD|$level|25000';
rollback;
"@)
  }
  $publishResult = Invoke-PsqlSql -Connection $Connection -PsqlPath $PsqlPath -Sql ($publishSql -join "`n") -ApplicationName "sitaa_sem01_ms08_isolation" -RunDirectory $Paths.Root -KeepRawLogs
  Assert-PsqlApproved -Result $publishResult -FailureCode "ms08_isolation_contract_rejected"
  $ms08Markers = @($publishResult.Stdout -split "\r?\n" | Where-Object { $_.StartsWith("MS08_GUARD|") })
  $after08 = Invoke-MutationFingerprint -Connection $Connection -PsqlPath $PsqlPath -RunDirectory $Paths.Root -Label "isolation_after08"
  $ms08 = New-ScenarioResult -ScenarioId "MS08_PUBLISH_REJECTS_HIGH_ISOLATION" -Outcome "25000_before_publish" -Assertions ([ordered]@{
    BothIsolationLevelsRejected = ($ms08Markers.Count -eq 2)
    ExactContractObserved = (($ms08Markers -join "`n") -match 'repeatable read\|25000' -and ($ms08Markers -join "`n") -match 'serializable\|25000')
    ZeroMutation = ($after08 -ceq $before)
  })
  Approve-ScenarioResult -ApprovedResults $ApprovedResults -Manifest $Manifest -Paths $Paths -Result $ms08

  Set-CurrentScenario -ScenarioId "MS09_ACTIVITY_DML_REJECTS_HIGH_ISOLATION"
  $dmlSql = New-Object System.Collections.ArrayList
  foreach ($level in @("repeatable read", "serializable")) {
    [void]$dmlSql.Add(@"
begin isolation level $level;
select set_config('request.jwt.claim.sub', '$AuthorityId', true);
set local role authenticated;
do `$ms09`$ begin
  begin
    update public.activities set start_date = start_date where id = '$ActivityId'::uuid;
    raise exception 'ms09_unexpected_success';
  exception when sqlstate '25000' then
    if sqlerrm <> 'sitaa_sem01_read_committed_required' then raise; end if;
  end;
end; `$ms09`$;
select 'MS09_GUARD|$level|25000';
rollback;
"@)
  }
  $dmlResult = Invoke-PsqlSql -Connection $Connection -PsqlPath $PsqlPath -Sql ($dmlSql -join "`n") -ApplicationName "sitaa_sem01_ms09_isolation" -RunDirectory $Paths.Root -KeepRawLogs
  Assert-PsqlApproved -Result $dmlResult -FailureCode "ms09_isolation_contract_rejected"
  $ms09Markers = @($dmlResult.Stdout -split "\r?\n" | Where-Object { $_.StartsWith("MS09_GUARD|") })
  $after09 = Invoke-MutationFingerprint -Connection $Connection -PsqlPath $PsqlPath -RunDirectory $Paths.Root -Label "isolation_after09"
  $ms09 = New-ScenarioResult -ScenarioId "MS09_ACTIVITY_DML_REJECTS_HIGH_ISOLATION" -Outcome "25000_before_activity_dml" -Assertions ([ordered]@{
    BothIsolationLevelsRejected = ($ms09Markers.Count -eq 2)
    ExactContractObserved = (($ms09Markers -join "`n") -match 'repeatable read\|25000' -and ($ms09Markers -join "`n") -match 'serializable\|25000')
    ZeroMutation = ($after09 -ceq $before)
  })
  Approve-ScenarioResult -ApprovedResults $ApprovedResults -Manifest $Manifest -Paths $Paths -Result $ms09

  Set-CurrentScenario -ScenarioId "MS10_READ_COMMITTED_NORMAL_PATH"
  $normalSql = @"
begin isolation level read committed;
select set_config('request.jwt.claim.sub', '$AuthorityId', true);
set local role authenticated;
with target as (
  select * from public.academic_periods where is_active and code <> 'pilot' order by starts_on limit 1
), changed as (
  select * from public.correct_admin_academic_period(
    (select id from target), (select name || ' LAB' from target),
    (select starts_on from target), (select ends_on from target), 'Corrección sintética multisesión'
  )
)
select 'MS10_ADMIN_MUTATION|' || count(*) from changed;
with changed as (
  update public.activities set description = description || ' [read committed]'
  where id = '$ActivityId'::uuid returning id
)
select 'MS10_ACTIVITY_DML|' || count(*) from changed;
select 'MS10_PUBLISH|' || count(*) from public.publish_activity('$ActivityId'::uuid);
rollback;
"@
  $normalResult = Invoke-PsqlSql -Connection $Connection -PsqlPath $PsqlPath -Sql $normalSql -ApplicationName "sitaa_sem01_ms10_normal" -RunDirectory $Paths.Root -KeepRawLogs
  Assert-PsqlApproved -Result $normalResult -FailureCode "ms10_normal_path_rejected"
  $normalAdmin = Get-MarkerParts -Result $normalResult -Marker "MS10_ADMIN_MUTATION"
  $normalDml = Get-MarkerParts -Result $normalResult -Marker "MS10_ACTIVITY_DML"
  $normalPublish = Get-MarkerParts -Result $normalResult -Marker "MS10_PUBLISH"
  $after10 = Invoke-MutationFingerprint -Connection $Connection -PsqlPath $PsqlPath -RunDirectory $Paths.Root -Label "isolation_after10"
  $ms10 = New-ScenarioResult -ScenarioId "MS10_READ_COMMITTED_NORMAL_PATH" -Outcome "three_real_mutations_rolled_back" -Assertions ([ordered]@{
    AdministrativeMutationSucceeded = ($normalAdmin[1] -eq "1")
    ActivityDmlSucceeded = ($normalDml[1] -eq "1")
    PublishSucceeded = ($normalPublish[1] -eq "1")
    SubsequentZeroResidue = ($after10 -ceq $before)
  })
  Approve-ScenarioResult -ApprovedResults $ApprovedResults -Manifest $Manifest -Paths $Paths -Result $ms10
}

function Test-LocalPsqlWorkerAlive {
  param([AllowNull()][object]$Worker)
  if ($null -eq $Worker -or $null -eq $Worker.Process) { return $false }
  try { return -not [bool]$Worker.Process.HasExited }
  catch { return $false }
}

function Start-StagedRuntimeAdvisoryHolder {
  param(
    [Parameter(Mandatory = $true)][object]$Connection,
    [Parameter(Mandatory = $true)][string]$PsqlPath,
    [Parameter(Mandatory = $true)][string]$RunDirectory,
    [Parameter(Mandatory = $true)][string]$SqlFile,
    [Parameter(Mandatory = $true)][object]$DisposableSqlOwnershipState,
    [Parameter(Mandatory = $true)][string]$ApplicationName,
    [Parameter(Mandatory = $true)][ValidatePattern('^(?:MS06_ROLLBACK_HOLDER_LOCKED|MS1[1-7]_HOLDER_OPERATION_READY)$')][string]$ReadyMarker,
    [Parameter(Mandatory = $true)][ValidatePattern('^(?:MS06_ROLLBACK_HOLDER_RELEASED|MS1[1-7]_HOLDER_RELEASED)$')][string]$ReleaseMarker
  )
  Assert-DisposableWorkerSqlPath -SqlFile $SqlFile -RunDirectory $RunDirectory
  Assert-PsqlDisposableOwnershipInvariant -State $DisposableSqlOwnershipState
  Assert-Condition -Condition ([string]$DisposableSqlOwnershipState.OwnerState -ceq "controller") `
    -Code "staged_runtime_holder_controller_ownership_missing" -FailureClass "source_integrity_rejection"
  Assert-Condition -Condition ($ApplicationName -cmatch '^sitaa_sem01_[a-z0-9_]{1,48}$') -Code "staged_runtime_holder_application_name_rejected" -FailureClass "source_integrity_rejection"
  $stageA = [System.IO.File]::ReadAllText($SqlFile, [System.Text.UTF8Encoding]::new($false))
  Assert-Condition -Condition ($stageA.Contains("select '$ReadyMarker|1';") -and $stageA -notmatch '(?i)\bpg_sleep\s*\(' -and
    $stageA -notmatch '(?im)^\s*(commit|rollback)\s*;') -Code "staged_runtime_holder_stage_a_rejected" -FailureClass "source_integrity_rejection"
  $stageB = "rollback;`nselect '$ReleaseMarker|1';"
  $stdoutLines = New-Object System.Collections.ArrayList
  $stderrLines = New-Object System.Collections.ArrayList
  $executionContext = if (Test-ObjectProperty -Value $Connection -Name "ExecutionContext") { $Connection.ExecutionContext } else { $null }
  Assert-PsqlDisposableStarterPreconditions -State $DisposableSqlOwnershipState
  $startInfo = New-StagedPsqlStartInfo -PsqlPath $PsqlPath -Connection $Connection -ApplicationName $ApplicationName `
    -StatementTimeoutMilliseconds 70000 -LockTimeoutMilliseconds 30000
  $DisposableSqlOwnershipState.StartInfo = $startInfo
  $processStartState = [pscustomobject]@{
    Process = $null; ProcessStarted = $false; Worker = $null; StartInfo = $startInfo
    StartInfoMaterialClearAttempted = $false; StartInfoMaterialCleared = $false
    StandardInputCloseAttempted = $false; ProcessTerminationAttempted = $false; ProcessTerminationObserved = $false
    LocalPidAddAttempted = $false; LocalPidRecorded = $false; LocalPidRemovalAttempted = $false
    ExecutePidAddAttempted = $false; ExecutePidRecorded = $false; ExecutePidRemovalAttempted = $false
    RunDirectory = $RunDirectory; ApplicationName = $ApplicationName; ExecutionContext = $executionContext
    CleanupResult = $null; PrimaryErrorRecord = $null; RethrowErrorRecord = $null
  }
  $process = $null
  $processStarted = $false
  try {
    $process = New-Object System.Diagnostics.Process
    $process.StartInfo = $startInfo
    Assert-Condition -Condition ($process.Start()) -Code "staged_runtime_holder_start_rejected" -FailureClass "worker_crash"
    $processStarted = $true
    $processStartState.Process = $process
    $processStartState.ProcessStarted = $true
    $DisposableSqlOwnershipState.Process = $process
    $DisposableSqlOwnershipState.ProcessStartObserved = $true
    $DisposableSqlOwnershipState.OwnerState = "starter"
    $processId = Get-PsqlProcessId -Process $process
    $DisposableSqlOwnershipState.ProcessId = $processId
    $DisposableSqlOwnershipState.ProcessIdObserved = $true
    Clear-PsqlStartInfoMaterial -State $DisposableSqlOwnershipState -StartInfo $startInfo
    $processStartState.StartInfoMaterialClearAttempted = $DisposableSqlOwnershipState.StartInfoMaterialClearAttempted
    $processStartState.StartInfoMaterialCleared = $DisposableSqlOwnershipState.StartInfoMaterialCleared
    $worker = [pscustomobject]@{
      Process = $process
      StdoutLines = $stdoutLines
      StderrLines = $stderrLines
      StdoutReadTask = $process.StandardOutput.ReadLineAsync()
      StderrReadTask = $process.StandardError.ReadLineAsync()
      StageA = $stageA
      StageB = $stageB
      StageState = "started"
      ApplicationName = $ApplicationName
      RunDirectory = $RunDirectory
      ExecutionContext = $executionContext
      StartedAt = [DateTime]::UtcNow
      SqlFile = $SqlFile
      DeleteSqlFileOnCompletion = $true
      ProcessStartState = $DisposableSqlOwnershipState
      DisposableSqlOwnershipState = $DisposableSqlOwnershipState
      ReadyMarker = $ReadyMarker
      ReleaseMarker = $ReleaseMarker
    }
    $processStartState.Worker = $worker
    $processStartState.LocalPidAddAttempted = $true
    $DisposableSqlOwnershipState.LocalPidAddAttempted = $true
    Update-WorkerPidManifest -RunDirectory $RunDirectory -ProcessId $processId -ApplicationName $ApplicationName -Operation "add"
    $processStartState.LocalPidRecorded = $true
    $DisposableSqlOwnershipState.LocalPidRecorded = $true
    if ($null -ne $executionContext) {
      $processStartState.ExecutePidAddAttempted = $true
      $DisposableSqlOwnershipState.ExecutePidAddAttempted = $true
      Update-ExecuteWorkerManifest -ExecutionContext $executionContext -ProcessId $processId -Operation "add"
      $processStartState.ExecutePidRecorded = $true
      $DisposableSqlOwnershipState.ExecutePidRecorded = $true
    }
    Assert-Condition -Condition ($processStartState.LocalPidRecorded -and
      ($null -eq $executionContext -or $processStartState.ExecutePidRecorded)) -Code "staged_runtime_holder_ownership_incomplete" -FailureClass "postcondition_rejection"
    Assert-Condition -Condition ($DisposableSqlOwnershipState.StartInfoMaterialClearAttempted -and
      $DisposableSqlOwnershipState.StartInfoMaterialCleared -and
      -not (Test-PsqlStartInfoContainsPgMaterial -StartInfo $startInfo) -and
      $DisposableSqlOwnershipState.ProcessStartObserved -and $DisposableSqlOwnershipState.ProcessIdObserved -and
      [int]$DisposableSqlOwnershipState.ProcessId -eq [int]$processId -and
      $DisposableSqlOwnershipState.LocalPidRecorded -and
      ($null -eq $executionContext -or $DisposableSqlOwnershipState.ExecutePidRecorded) -and
      $null -ne $worker.StdoutReadTask -and $null -ne $worker.StderrReadTask -and
      [object]::ReferenceEquals($worker.Process, $DisposableSqlOwnershipState.Process) -and
      [object]::ReferenceEquals($worker.DisposableSqlOwnershipState, $DisposableSqlOwnershipState)) `
      -Code "staged_runtime_holder_worker_candidate_incomplete" -FailureClass "postcondition_rejection"
    [void](Assert-PsqlDisposableFrozenIdentity -State $DisposableSqlOwnershipState)
    Set-PsqlDisposableWorkerOwnership -State $DisposableSqlOwnershipState -Worker $worker
    return $worker
  }
  catch {
    $primaryError = $_
    $processStartState.PrimaryErrorRecord = $_
    if ($null -eq $DisposableSqlOwnershipState.PrimaryErrorRecord) {
      $DisposableSqlOwnershipState.PrimaryErrorRecord = $primaryError
      $DisposableSqlOwnershipState.PrimaryFailureClass = [string]$primaryError.Exception.Data["FailureClass"]
      $DisposableSqlOwnershipState.PrimaryScenario = [string]$script:CurrentScenario
    }
    $processStartState.CleanupResult = Invoke-StagedProcessStartFailureCleanup -State $processStartState -NamePrefix "RUNTIME_HOLDER_START" `
      -FallbackProcess $process -FallbackProcessStarted $processStarted -FallbackStartInfo $startInfo
    $DisposableSqlOwnershipState.ProcessTerminationObserved = [bool]$processStartState.ProcessTerminationObserved
    $DisposableSqlOwnershipState.LocalPidRemovalAttempted = [bool]$processStartState.LocalPidRemovalAttempted
    $DisposableSqlOwnershipState.LocalPidRecorded = [bool]$processStartState.LocalPidRecorded
    $DisposableSqlOwnershipState.ExecutePidRemovalAttempted = [bool]$processStartState.ExecutePidRemovalAttempted
    $DisposableSqlOwnershipState.ExecutePidRecorded = [bool]$processStartState.ExecutePidRecorded
    if ($processStartState.ProcessTerminationObserved -and [string]$DisposableSqlOwnershipState.OwnerState -ceq "starter") {
      $disposableCleanup = Invoke-PsqlDisposableStarterCleanup -State $DisposableSqlOwnershipState
      $DisposableSqlOwnershipState.SecondaryCleanupErrors = @($DisposableSqlOwnershipState.SecondaryCleanupErrors) + @($disposableCleanup.SecondaryErrors)
    }
    elseif ($processStartState.ProcessTerminationObserved -and [string]$DisposableSqlOwnershipState.OwnerState -ceq "worker") {
      $workerCleanup = Invoke-OrchestrationCleanup -EmitFailureMarkers -CleanupOperations @(
        [pscustomobject]@{ Name = "RUNTIME_HOLDER_WORKER_HANDOFF_CLEANUP"; Operation = {
          Assert-PsqlDisposableOwnershipInvariant -State $DisposableSqlOwnershipState
          Assert-Condition -Condition ($null -ne $DisposableSqlOwnershipState.Worker -and
            [object]::ReferenceEquals($DisposableSqlOwnershipState.Worker, $worker)) `
            -Code "staged_runtime_holder_partial_worker_rejected" -FailureClass "postcondition_rejection"
          Remove-DisposableWorkerSqlFile -Worker $DisposableSqlOwnershipState.Worker
          Complete-PsqlDisposableWorkerOwnership -State $DisposableSqlOwnershipState
        } }
      )
      $DisposableSqlOwnershipState.SecondaryCleanupErrors = @($DisposableSqlOwnershipState.SecondaryCleanupErrors) + @($workerCleanup.SecondaryErrors)
    }
    elseif ($processStartState.ProcessTerminationObserved -and [string]$DisposableSqlOwnershipState.OwnerState -ceq "controller") {
      $disposableCleanup = Invoke-PsqlDisposableControllerCleanup -State $DisposableSqlOwnershipState
      $DisposableSqlOwnershipState.SecondaryCleanupErrors = @($DisposableSqlOwnershipState.SecondaryCleanupErrors) + @($disposableCleanup.SecondaryErrors)
    }
    $processStartState.RethrowErrorRecord = $primaryError
    throw $primaryError
  }
}

function Wait-StagedRuntimeAdvisoryHolderMarker {
  param(
    [Parameter(Mandatory = $true)][object]$Worker,
    [Parameter(Mandatory = $true)][string]$Marker,
    [Parameter(Mandatory = $true)][object]$StageRequest,
    [ValidateRange(1, 600000)][int]$TimeoutMilliseconds = $script:ObserverTimeoutMilliseconds
  )
  $expectedStage = if ($Marker -ceq [string]$Worker.ReadyMarker) { "A" } elseif ($Marker -ceq [string]$Worker.ReleaseMarker) { "B" } else { "" }
  Assert-Condition -Condition ($expectedStage -ne "" -and [string]$StageRequest.Stage -ceq $expectedStage -and
    [long]$StageRequest.SentMonotonicTimestamp -ge 0) -Code "staged_runtime_holder_marker_request_rejected" -FailureClass "source_integrity_rejection"
  while ($true) {
    $beforeReadTimestamp = Get-MonotonicTimestamp
    $beforeReadElapsed = Get-MonotonicElapsedMilliseconds -StartTimestamp ([long]$StageRequest.SentMonotonicTimestamp) -EndTimestamp $beforeReadTimestamp
    Assert-HardMonotonicDeadline -ElapsedMilliseconds $beforeReadElapsed -TimeoutMilliseconds $TimeoutMilliseconds -FailureCode "staged_runtime_holder_marker_timeout"
    Read-StagedPsqlWorkerStreams -Worker $Worker
    if ($ValidateOnly -and (Test-ObjectProperty -Value $Worker -Name "FixtureMarkerAfterReadLine") -and
      -not [string]::IsNullOrWhiteSpace([string]$Worker.FixtureMarkerAfterReadLine) -and
      -not $Worker.FixtureMarkerAfterReadInjected) {
      [void]$Worker.StdoutLines.Add([string]$Worker.FixtureMarkerAfterReadLine)
      $Worker.FixtureMarkerAfterReadInjected = $true
    }
    $postReadMonotonicTimestamp = Get-MonotonicTimestamp
    $postReadElapsedMilliseconds = Get-MonotonicElapsedMilliseconds `
      -StartTimestamp ([long]$StageRequest.SentMonotonicTimestamp) -EndTimestamp $postReadMonotonicTimestamp
    $matches = @($Worker.StdoutLines | Where-Object { ([string]$_).StartsWith($Marker + "|", [System.StringComparison]::Ordinal) })
    Assert-Condition -Condition ($matches.Count -le 1) -Code "staged_runtime_holder_marker_duplicate_rejected" -FailureClass "source_integrity_rejection"
    if ($matches.Count -eq 1) {
      Assert-HardMonotonicDeadline -ElapsedMilliseconds $postReadElapsedMilliseconds -TimeoutMilliseconds $TimeoutMilliseconds `
        -FailureCode "staged_runtime_holder_marker_late_response_rejected"
      $parts = @(([string]$matches[0]).Split('|'))
      Assert-Condition -Condition ($parts.Count -eq 2 -and $parts[1] -ceq "1") -Code "staged_runtime_holder_marker_value_rejected"
      $acceptedMonotonicTimestamp = Get-MonotonicTimestamp
      $acceptedElapsedMilliseconds = Get-MonotonicElapsedMilliseconds `
        -StartTimestamp ([long]$StageRequest.SentMonotonicTimestamp) -EndTimestamp $acceptedMonotonicTimestamp
      Assert-HardMonotonicDeadline -ElapsedMilliseconds $acceptedElapsedMilliseconds -TimeoutMilliseconds $TimeoutMilliseconds `
        -FailureCode "staged_runtime_holder_marker_late_response_rejected"
      if ($expectedStage -ceq "A") { Confirm-StagedWorkerStageA -Worker $Worker -ProcessHasExited $Worker.Process.HasExited }
      return [pscustomobject]@{
        Marker = $Marker
        Value = "1"
        CommandElapsedMilliseconds = [double]$acceptedElapsedMilliseconds
        SentMonotonicTimestamp = [long]$StageRequest.SentMonotonicTimestamp
        ObservedMonotonicTimestamp = [long]$acceptedMonotonicTimestamp
      }
    }
    Assert-HardMonotonicDeadline -ElapsedMilliseconds $postReadElapsedMilliseconds -TimeoutMilliseconds $TimeoutMilliseconds `
      -FailureCode "staged_runtime_holder_marker_timeout"
    Assert-Condition -Condition (-not $Worker.Process.HasExited) -Code "staged_runtime_holder_exited_before_marker" -FailureClass "worker_crash"
    Start-Sleep -Milliseconds $script:ObserverPollMilliseconds
  }
}

function Send-StagedRuntimeAdvisoryHolderStage {
  param(
    [Parameter(Mandatory = $true)][object]$Worker,
    [Parameter(Mandatory = $true)][ValidateSet("A", "B")][string]$Stage
  )
  return Send-StagedInstallationHolderStage -Worker $Worker -Stage $Stage
}

function Stop-StagedRuntimeAdvisoryHolder {
  param([AllowNull()][object]$Worker)
  if ($null -eq $Worker) { return }
  Stop-StagedInstallationHolder -Worker $Worker
  Remove-DisposableWorkerSqlFile -Worker $Worker
  Complete-PsqlDisposableWorkerOwnership -State $Worker.DisposableSqlOwnershipState
}

function Get-RollbackRelationHolderStageASql {
  return @'
begin;
lock table public.activities in row exclusive mode;
select 'MS06_ROLLBACK_HOLDER_LOCKED|1';
'@
}

function Start-StagedRollbackRelationHolder {
  param(
    [Parameter(Mandatory = $true)][object]$Connection,
    [Parameter(Mandatory = $true)][string]$PsqlPath,
    [Parameter(Mandatory = $true)][string]$RunDirectory,
    [Parameter(Mandatory = $true)][string]$SqlFile,
    [Parameter(Mandatory = $true)][object]$DisposableSqlOwnershipState
  )
  $expectedStageA = (Get-RollbackRelationHolderStageASql).Trim() + "`n"
  $observedStageA = [System.IO.File]::ReadAllText($SqlFile, [System.Text.UTF8Encoding]::new($false)).Replace("`r`n", "`n").Replace("`r", "`n")
  Assert-Condition -Condition ($observedStageA -ceq $expectedStageA -and
    $observedStageA -notmatch '(?i)\bpg_sleep\s*\(' -and
    $observedStageA -notmatch '(?im)^\s*(commit|rollback)\s*;') `
    -Code "ms06_rollback_holder_stage_a_rejected" -FailureClass "source_integrity_rejection"
  return Start-StagedRuntimeAdvisoryHolder -Connection $Connection -PsqlPath $PsqlPath -RunDirectory $RunDirectory `
    -SqlFile $SqlFile -DisposableSqlOwnershipState $DisposableSqlOwnershipState `
    -ApplicationName "sitaa_sem01_rollback_holder" -ReadyMarker "MS06_ROLLBACK_HOLDER_LOCKED" `
    -ReleaseMarker "MS06_ROLLBACK_HOLDER_RELEASED"
}

function Send-StagedRollbackRelationHolderStage {
  param(
    [Parameter(Mandatory = $true)][object]$Worker,
    [Parameter(Mandatory = $true)][ValidateSet("A", "B")][string]$Stage,
    [bool]$Exact55P03Observed = $false,
    [bool]$PostRejectionHolderObserved = $false,
    [bool]$Post0011FingerprintPreserved = $false
  )
  if ($Stage -ceq "B") {
    Assert-Condition -Condition ($Exact55P03Observed -and $PostRejectionHolderObserved -and $Post0011FingerprintPreserved) `
      -Code "ms06_rollback_holder_release_gate_rejected" -FailureClass "source_integrity_rejection"
  }
  return Send-StagedRuntimeAdvisoryHolderStage -Worker $Worker -Stage $Stage
}

function Wait-StagedRollbackRelationHolderMarker {
  param(
    [Parameter(Mandatory = $true)][object]$Worker,
    [Parameter(Mandatory = $true)][ValidateSet("MS06_ROLLBACK_HOLDER_LOCKED", "MS06_ROLLBACK_HOLDER_RELEASED")][string]$Marker,
    [Parameter(Mandatory = $true)][object]$StageRequest,
    [ValidateRange(1, 600000)][int]$TimeoutMilliseconds = $script:ObserverTimeoutMilliseconds
  )
  return Wait-StagedRuntimeAdvisoryHolderMarker -Worker $Worker -Marker $Marker -StageRequest $StageRequest `
    -TimeoutMilliseconds $TimeoutMilliseconds
}

function Wait-StagedRollbackRelationHolder {
  param(
    [Parameter(Mandatory = $true)][object]$Worker,
    [ValidateRange(1, 600000)][int]$TimeoutMilliseconds = 30000,
    [switch]$KeepRawLogs
  )
  $result = Wait-StagedInstallationHolder -Worker $Worker -TimeoutMilliseconds $TimeoutMilliseconds -KeepRawLogs:$KeepRawLogs
  $Worker.DisposableSqlOwnershipState.ProcessTerminationObserved = [bool]$Worker.Process.HasExited
  Remove-DisposableWorkerSqlFile -Worker $Worker
  Complete-PsqlDisposableWorkerOwnership -State $Worker.DisposableSqlOwnershipState
  return $result
}

function Stop-StagedRollbackRelationHolder {
  param([AllowNull()][object]$Worker)
  if ($null -eq $Worker) { return }
  Stop-StagedInstallationHolder -Worker $Worker
  $Worker.DisposableSqlOwnershipState.ProcessTerminationObserved = [bool]$Worker.Process.HasExited
  Remove-DisposableWorkerSqlFile -Worker $Worker
  Complete-PsqlDisposableWorkerOwnership -State $Worker.DisposableSqlOwnershipState
}

function Get-RollbackRelationHolderObservationSql {
  param([ValidateRange(0, 2147483647)][int]$ExpectedBackendPid = 0)
  return @"
begin;
set transaction read only;
with holder_sessions as materialized (
  select activity.pid, activity.state, activity.backend_type
  from pg_catalog.pg_stat_activity activity
  where activity.application_name = 'sitaa_sem01_rollback_holder'
), holder_locks as materialized (
  select lock_info.pid
  from holder_sessions session_info
  join pg_catalog.pg_locks lock_info on lock_info.pid = session_info.pid
  where lock_info.locktype = 'relation'
    and lock_info.relation = 'public.activities'::regclass
    and lock_info.mode = 'RowExclusiveLock'
    and lock_info.granted
), observation as (
  select
    (select count(*) from holder_sessions) as exact_holder_count,
    coalesce((select bool_and(backend_type = 'client backend') from holder_sessions), false) as exact_backend_type,
    coalesce((select bool_and(state = 'idle in transaction') from holder_sessions), false) as idle_in_transaction,
    (select count(*) from holder_locks) as exact_relation_lock_count,
    (select count(*) from pg_catalog.pg_stat_activity where application_name = 'sitaa_sem01_rollback_contended') as contended_session_count,
    coalesce((select pid from holder_sessions limit 1), 0) as internal_holder_pid
), accepted as (
  select *, exact_holder_count = 1 and exact_backend_type and idle_in_transaction
    and exact_relation_lock_count = 1 and contended_session_count = 0
    and ($ExpectedBackendPid = 0 or internal_holder_pid = $ExpectedBackendPid) as satisfied
  from observation
)
select 'MS06_ROLLBACK_HOLDER_STATE|' || satisfied::int || '|' || exact_holder_count || '|' ||
  exact_backend_type::int || '|' || idle_in_transaction::int || '|' || exact_relation_lock_count || '|' ||
  contended_session_count || '|' || internal_holder_pid
from accepted;
rollback;
"@
}

function ConvertFrom-RollbackRelationHolderObservation {
  param([Parameter(Mandatory = $true)][object]$Result)
  $parts = Get-MarkerParts -Result $Result -Marker "MS06_ROLLBACK_HOLDER_STATE"
  Assert-Condition -Condition ($parts.Count -eq 8) -Code "ms06_rollback_holder_observation_shape_rejected"
  return [pscustomobject]@{
    Satisfied = ($parts[1] -ceq "1")
    ExactHolderCount = [int]$parts[2]
    ExactBackendType = ($parts[3] -ceq "1")
    IdleInTransaction = ($parts[4] -ceq "1")
    ExactRelationLockCount = [int]$parts[5]
    ContendedSessionCount = [int]$parts[6]
    InternalHolderBackendPid = [int]$parts[7]
    LocalHolderProcessAlive = $false
  }
}

function Test-ExactRollbackRelationHolderEvidence {
  param(
    [Parameter(Mandatory = $true)][object]$Evidence,
    [ValidateRange(0, 2147483647)][int]$ExpectedBackendPid = 0
  )
  return ($Evidence.ExactHolderCount -eq 1 -and $Evidence.ExactBackendType -and $Evidence.IdleInTransaction -and
    $Evidence.ExactRelationLockCount -eq 1 -and $Evidence.ContendedSessionCount -eq 0 -and
    $Evidence.InternalHolderBackendPid -gt 0 -and
    ($ExpectedBackendPid -eq 0 -or $Evidence.InternalHolderBackendPid -eq $ExpectedBackendPid) -and
    $Evidence.LocalHolderProcessAlive)
}

function Invoke-RollbackRelationHolderObservationProbe {
  param(
    [Parameter(Mandatory = $true)][object]$Connection,
    [Parameter(Mandatory = $true)][string]$PsqlPath,
    [Parameter(Mandatory = $true)][string]$RunDirectory,
    [Parameter(Mandatory = $true)][object]$HolderWorker,
    [ValidateRange(0, 2147483647)][int]$ExpectedBackendPid = 0
  )
  if (-not (Test-LocalPsqlWorkerAlive -Worker $HolderWorker)) {
    return [pscustomobject]@{
      Satisfied = $false
      Evidence = [pscustomobject]@{
        Satisfied = $false; ExactHolderCount = 0; ExactBackendType = $false; IdleInTransaction = $false
        ExactRelationLockCount = 0; ContendedSessionCount = 0; InternalHolderBackendPid = 0; LocalHolderProcessAlive = $false
      }
      TerminalFailureCode = "ms06_rollback_holder_process_exited_before_readiness"
    }
  }
  $probe = Invoke-PsqlSql -Connection $Connection -PsqlPath $PsqlPath `
    -Sql (Get-RollbackRelationHolderObservationSql -ExpectedBackendPid $ExpectedBackendPid) `
    -ApplicationName "sitaa_sem01_rollback_holder_observer" -RunDirectory $RunDirectory `
    -StatementTimeoutMilliseconds $script:ObserverProbeCommandTimeoutMilliseconds `
    -LockTimeoutMilliseconds $script:ObserverProbeCommandTimeoutMilliseconds `
    -ProcessTimeoutMilliseconds $script:ObserverProbeProcessTimeoutMilliseconds
  if ($probe.ExitCode -ne 0 -or $probe.TimedOut) {
    Throw-StableFailure -Code "observer_probe_failed" -FailureClass "worker_crash"
  }
  $evidence = ConvertFrom-RollbackRelationHolderObservation -Result $probe
  $evidence.LocalHolderProcessAlive = Test-LocalPsqlWorkerAlive -Worker $HolderWorker
  $satisfied = Test-ExactRollbackRelationHolderEvidence -Evidence $evidence -ExpectedBackendPid $ExpectedBackendPid
  Assert-Condition -Condition (($evidence.Satisfied -and $evidence.LocalHolderProcessAlive) -eq $satisfied) `
    -Code "ms06_rollback_holder_observation_decision_rejected" -FailureClass "source_integrity_rejection"
  return [pscustomobject]@{ Satisfied = $satisfied; Evidence = $evidence; TerminalFailureCode = $null }
}

function Wait-ForExactRollbackRelationHolder {
  param(
    [Parameter(Mandatory = $true)][object]$Connection,
    [Parameter(Mandatory = $true)][string]$PsqlPath,
    [Parameter(Mandatory = $true)][string]$RunDirectory,
    [Parameter(Mandatory = $true)][object]$HolderWorker,
    [Parameter(Mandatory = $true)][ValidateSet(0, 1)][int]$ContendedRollbackStartCount,
    [ValidateRange(0, 2147483647)][int]$ExpectedBackendPid = 0,
    [ValidateRange(1, 600000)][int]$TimeoutMilliseconds = $script:ObserverTimeoutMilliseconds
  )
  if ($ExpectedBackendPid -eq 0) {
    Assert-Condition -Condition ($ContendedRollbackStartCount -eq 0) -Code "ms06_contended_rollback_started_before_holder_readiness"
  }
  $observation = Wait-ForObserverCondition -FailureCode "ms06_rollback_holder_readiness_not_observed" `
    -TimeoutMilliseconds $TimeoutMilliseconds -Probe {
      Invoke-RollbackRelationHolderObservationProbe -Connection $Connection -PsqlPath $PsqlPath -RunDirectory $RunDirectory `
        -HolderWorker $HolderWorker -ExpectedBackendPid $ExpectedBackendPid
    }
  Assert-Condition -Condition ($observation.Satisfied -and
    (Test-ExactRollbackRelationHolderEvidence -Evidence $observation.Evidence -ExpectedBackendPid $ExpectedBackendPid)) `
    -Code "ms06_rollback_holder_readiness_not_observed"
  return $observation
}

function Get-RollbackRelationHolderAbsenceSql {
  param(
    [Parameter(Mandatory = $true)][ValidateRange(1, 2147483647)][int]$ExpectedBackendPid,
    [Parameter(Mandatory = $true)][bool]$RequireSessionAbsent
  )
  $sessionPredicate = if ($RequireSessionAbsent) { "exact_holder_count = 0" } else { "exact_holder_count -le 1" }
  return @"
begin;
set transaction read only;
with observation as (
  select
    (select count(*) from pg_catalog.pg_stat_activity where application_name = 'sitaa_sem01_rollback_holder') as exact_holder_count,
    (select count(*) from pg_catalog.pg_locks lock_info
      where lock_info.pid = $ExpectedBackendPid and lock_info.locktype = 'relation'
        and lock_info.relation = 'public.activities'::regclass
        and lock_info.mode = 'RowExclusiveLock' and lock_info.granted) as frozen_holder_lock_count
)
select 'MS06_ROLLBACK_HOLDER_ABSENCE|' || (($sessionPredicate) and frozen_holder_lock_count = 0)::int || '|' ||
  exact_holder_count || '|' || frozen_holder_lock_count
from observation;
rollback;
"@
}

function Wait-ForRollbackRelationHolderAbsence {
  param(
    [Parameter(Mandatory = $true)][object]$Connection,
    [Parameter(Mandatory = $true)][string]$PsqlPath,
    [Parameter(Mandatory = $true)][string]$RunDirectory,
    [Parameter(Mandatory = $true)][ValidateRange(1, 2147483647)][int]$ExpectedBackendPid,
    [Parameter(Mandatory = $true)][bool]$RequireSessionAbsent
  )
  return Wait-ForObserverCondition -FailureCode "ms06_rollback_holder_absence_not_observed" -Probe {
    $probe = Invoke-PsqlSql -Connection $Connection -PsqlPath $PsqlPath `
      -Sql (Get-RollbackRelationHolderAbsenceSql -ExpectedBackendPid $ExpectedBackendPid -RequireSessionAbsent $RequireSessionAbsent) `
      -ApplicationName "sitaa_sem01_rollback_absence_observer" -RunDirectory $RunDirectory `
      -StatementTimeoutMilliseconds $script:ObserverProbeCommandTimeoutMilliseconds `
      -LockTimeoutMilliseconds $script:ObserverProbeCommandTimeoutMilliseconds `
      -ProcessTimeoutMilliseconds $script:ObserverProbeProcessTimeoutMilliseconds
    if ($probe.ExitCode -ne 0 -or $probe.TimedOut) { Throw-StableFailure -Code "observer_probe_failed" -FailureClass "worker_crash" }
    $parts = Get-MarkerParts -Result $probe -Marker "MS06_ROLLBACK_HOLDER_ABSENCE"
    Assert-Condition -Condition ($parts.Count -eq 4) -Code "ms06_rollback_holder_absence_shape_rejected"
    $satisfied = ($parts[1] -ceq "1" -and [int]$parts[3] -eq 0 -and
      (-not $RequireSessionAbsent -or [int]$parts[2] -eq 0))
    return [pscustomobject]@{
      Satisfied = $satisfied
      Evidence = [pscustomobject]@{ ExactHolderCount = [int]$parts[2]; FrozenHolderLockCount = [int]$parts[3] }
    }
  }
}

function Get-AdvisoryHolderObservationSql {
  param([Parameter(Mandatory = $true)][string]$HolderApplicationName)
  Assert-Condition -Condition ($HolderApplicationName -cmatch '^sitaa_sem01_[a-z0-9_]{1,48}$') `
    -Code "advisory_holder_application_name_rejected" -FailureClass "source_integrity_rejection"
  return @"
begin; set transaction read only;
with holder_sessions as (
  select activity.pid, activity.state, activity.backend_type
  from pg_catalog.pg_stat_activity activity
  where activity.application_name = '$HolderApplicationName'
), holder_state as (
  select
    (select count(*) from holder_sessions) as exact_holder_count,
    exists (
      select 1 from holder_sessions
      where state is not null and backend_type = 'client backend'
    ) as holder_alive,
    (
      select count(*)
      from holder_sessions session_info
      join pg_catalog.pg_locks lock_info on lock_info.pid = session_info.pid
      where lock_info.locktype = 'advisory'
        and lock_info.classid = $($script:Sem01AdvisoryKeyOne)
        and lock_info.objid = $($script:Sem01AdvisoryKeyTwo)
        and lock_info.objsubid = $($script:Sem01AdvisoryObjSubId)
        and lock_info.granted
    ) as exact_granted_holder_count,
    coalesce((select pid from holder_sessions limit 1), 0) as internal_holder_pid
), accepted as (
  select *, exact_holder_count = 1 and holder_alive and exact_granted_holder_count = 1 as satisfied
  from holder_state
)
select 'ADVISORY_HOLDER_STATE|' || satisfied::int || '|' || exact_holder_count || '|' || holder_alive::int || '|' ||
  (exact_granted_holder_count = 1)::int || '|' || exact_granted_holder_count || '|' || internal_holder_pid
from accepted;
rollback;
"@
}

function ConvertFrom-AdvisoryHolderObservation {
  param([Parameter(Mandatory = $true)][object]$Result)
  $state = Get-MarkerParts -Result $Result -Marker "ADVISORY_HOLDER_STATE"
  Assert-Condition -Condition ($state.Count -eq 7) -Code "advisory_holder_marker_shape_rejected"
  return [pscustomobject]@{
    Satisfied = ($state[1] -ceq "1")
    ExactHolderCount = [int]$state[2]
    HolderAlive = ($state[3] -ceq "1")
    HolderAdvisoryGranted = ($state[4] -ceq "1")
    ExactGrantedHolderCount = [int]$state[5]
    InternalHolderBackendPid = [int]$state[6]
    LocalHolderProcessAlive = $false
  }
}

function Test-ExactAdvisoryHolderEvidence {
  param([Parameter(Mandatory = $true)][object]$Evidence)
  return ($Evidence.ExactHolderCount -eq 1 -and $Evidence.HolderAlive -and
    $Evidence.HolderAdvisoryGranted -and $Evidence.ExactGrantedHolderCount -eq 1 -and
    $Evidence.InternalHolderBackendPid -gt 0 -and $Evidence.LocalHolderProcessAlive)
}

function Invoke-AdvisoryHolderObservationProbe {
  param(
    [Parameter(Mandatory = $true)][object]$Connection,
    [Parameter(Mandatory = $true)][string]$PsqlPath,
    [Parameter(Mandatory = $true)][string]$RunDirectory,
    [Parameter(Mandatory = $true)][string]$HolderApplicationName,
    [Parameter(Mandatory = $true)][string]$ObserverApplicationName,
    [Parameter(Mandatory = $true)][object]$HolderWorker
  )
  if (-not (Test-LocalPsqlWorkerAlive -Worker $HolderWorker)) {
    $exitedEvidence = [pscustomobject]@{
      Satisfied = $false; ExactHolderCount = 0; HolderAlive = $false; HolderAdvisoryGranted = $false
      ExactGrantedHolderCount = 0; InternalHolderBackendPid = 0; LocalHolderProcessAlive = $false
    }
    return [pscustomobject]@{
      Satisfied = $false
      Evidence = $exitedEvidence
      TerminalFailureCode = "advisory_holder_process_exited_before_readiness"
    }
  }
  $probeSql = Get-AdvisoryHolderObservationSql -HolderApplicationName $HolderApplicationName
  $probe = Invoke-PsqlSql -Connection $Connection -PsqlPath $PsqlPath -Sql $probeSql -ApplicationName $ObserverApplicationName `
    -RunDirectory $RunDirectory -StatementTimeoutMilliseconds $script:ObserverProbeCommandTimeoutMilliseconds `
    -LockTimeoutMilliseconds $script:ObserverProbeCommandTimeoutMilliseconds -ProcessTimeoutMilliseconds $script:ObserverProbeProcessTimeoutMilliseconds
  if ($probe.ExitCode -ne 0 -or $probe.TimedOut) {
    Throw-StableFailure -Code "observer_probe_failed" -FailureClass "worker_crash"
  }
  $evidence = ConvertFrom-AdvisoryHolderObservation -Result $probe
  $evidence.LocalHolderProcessAlive = Test-LocalPsqlWorkerAlive -Worker $HolderWorker
  $satisfied = Test-ExactAdvisoryHolderEvidence -Evidence $evidence
  Assert-Condition -Condition (($evidence.Satisfied -and $evidence.LocalHolderProcessAlive) -eq $satisfied) `
    -Code "advisory_holder_marker_decision_rejected" -FailureClass "source_integrity_rejection"
  return [pscustomobject]@{
    Satisfied = $satisfied
    Evidence = $evidence
    TerminalFailureCode = $(if ($evidence.LocalHolderProcessAlive) { $null } else { "advisory_holder_process_exited_before_readiness" })
  }
}

function Wait-ForExactAdvisoryHolder {
  param(
    [Parameter(Mandatory = $true)][object]$Connection,
    [Parameter(Mandatory = $true)][string]$PsqlPath,
    [Parameter(Mandatory = $true)][string]$RunDirectory,
    [Parameter(Mandatory = $true)][string]$HolderApplicationName,
    [Parameter(Mandatory = $true)][string]$ObserverApplicationName,
    [Parameter(Mandatory = $true)][object]$HolderWorker,
    [Parameter(Mandatory = $true)][int]$WaiterStartCount,
    [ValidateRange(1, 600000)][int]$TimeoutMilliseconds = $script:ObserverTimeoutMilliseconds
  )
  Assert-Condition -Condition ($WaiterStartCount -eq 0) -Code "advisory_waiter_started_before_holder_readiness"
  try {
    $observation = Wait-ForObserverCondition -FailureCode "advisory_holder_readiness_not_observed" -TimeoutMilliseconds $TimeoutMilliseconds -Probe {
      Invoke-AdvisoryHolderObservationProbe -Connection $Connection -PsqlPath $PsqlPath -RunDirectory $RunDirectory `
        -HolderApplicationName $HolderApplicationName -ObserverApplicationName $ObserverApplicationName -HolderWorker $HolderWorker
    }
  }
  catch {
    if ($_.Exception.Message -in @("observer_condition_not_observed", "observer_deadline_rejected")) {
      Throw-StableFailure -Code "advisory_holder_readiness_not_observed" -FailureClass "unexpected_timeout"
    }
    throw
  }
  Assert-Condition -Condition ($WaiterStartCount -eq 0 -and $observation.Satisfied -and
    (Test-ExactAdvisoryHolderEvidence -Evidence $observation.Evidence)) -Code "advisory_holder_readiness_not_observed"
  return $observation
}

function Start-AdvisoryWaiterAfterHolderReady {
  param(
    [Parameter(Mandatory = $true)][object]$HolderObservation,
    [Parameter(Mandatory = $true)][ref]$WaiterStartCount,
    [Parameter(Mandatory = $true)][scriptblock]$StartOperation
  )
  Assert-Condition -Condition ($WaiterStartCount.Value -eq 0) -Code "advisory_waiter_start_count_rejected"
  Assert-Condition -Condition ($HolderObservation.Satisfied -and
    (Test-ExactAdvisoryHolderEvidence -Evidence $HolderObservation.Evidence)) -Code "advisory_holder_readiness_not_observed"
  $worker = & $StartOperation
  Assert-Condition -Condition ($null -ne $worker) -Code "advisory_waiter_start_rejected" -FailureClass "worker_crash"
  $WaiterStartCount.Value = [int]$WaiterStartCount.Value + 1
  Assert-Condition -Condition ($WaiterStartCount.Value -eq 1) -Code "advisory_waiter_start_count_rejected"
  return $worker
}

function Test-SameAdvisoryHolderObservedInPair {
  param(
    [Parameter(Mandatory = $true)][object]$HolderObservation,
    [Parameter(Mandatory = $true)][object]$PairEvidence
  )
  return ($HolderObservation.Satisfied -and $PairEvidence.ExpectedHolderMatched -and
    $HolderObservation.Evidence.InternalHolderBackendPid -gt 0 -and
    $HolderObservation.Evidence.InternalHolderBackendPid -eq $PairEvidence.InternalHolderBackendPid)
}

function Test-ExactSem01AdvisoryLockRow {
  param(
    [Parameter(Mandatory = $true)][object]$Row,
    [Parameter(Mandatory = $true)][bool]$ExpectedGranted
  )
  return (Test-ObjectProperty -Value $Row -Name "ObjSubId") -and
    [string]$Row.LockType -ceq "advisory" -and [int64]$Row.ClassId -eq $script:Sem01AdvisoryKeyOne -and
    [int64]$Row.ObjId -eq $script:Sem01AdvisoryKeyTwo -and [int]$Row.ObjSubId -eq $script:Sem01AdvisoryObjSubId -and
    [bool]$Row.Granted -eq $ExpectedGranted
}

function Test-RuntimeDiagnosticCountsClean {
  param([Parameter(Mandatory = $true)][object]$Counts)
  return [int]$Counts.GrantedSem01AdvisoryLocks -eq 0 -and [int]$Counts.WaitingSem01AdvisoryLocks -eq 0 -and
    [int]$Counts.TotalSem01AdvisoryLocks -eq 0 -and [int]$Counts.TransientWorkerSqlFiles -eq 0
}

function Test-StagedRuntimeHolderReleaseEligible {
  param(
    [Parameter(Mandatory = $true)][ValidateSet("MS11_MS12", "MS13_MS17")][string]$Policy,
    [Parameter(Mandatory = $true)][bool]$OperationReadyObserved,
    [Parameter(Mandatory = $true)][bool]$ExactPairObserved,
    [bool]$WaiterCollected = $false,
    [AllowNull()][string]$WaiterSqlState,
    [bool]$WaiterSucceeded = $false,
    [bool]$HolderProcessHasExited = $false
  )
  if (-not $OperationReadyObserved -or -not $ExactPairObserved) { return $false }
  if ($Policy -ceq "MS11_MS12") {
    return $WaiterCollected -and -not $WaiterSucceeded -and [string]$WaiterSqlState -ceq "55P03"
  }
  return $true
}

function Invoke-SyntheticPairedSqlOwnershipModel {
  param([Parameter(Mandatory = $true)][ValidateSet("holder_file", "waiter_file", "fixture", "holder_start", "completed")][string]$FailurePoint)
  $state = New-PairedTransientSqlOwnershipState
  $removalAttempts = New-Object System.Collections.ArrayList
  try {
    if ($FailurePoint -ceq "holder_file") { throw "synthetic_holder_file_failure" }
    $state.HolderSqlFile = "synthetic_holder.sql"
    if ($FailurePoint -ceq "waiter_file") { throw "synthetic_waiter_file_failure" }
    $state.WaiterSqlFile = "synthetic_waiter.sql"
    if ($FailurePoint -ceq "fixture") { throw "synthetic_fixture_failure" }
    if ($FailurePoint -ceq "holder_start") { throw "synthetic_holder_start_failure" }
    $state.HolderSqlFile = $null
    $state.WaiterSqlFile = $null
  }
  catch { }
  foreach ($role in @("Holder", "Waiter")) {
    [void]$removalAttempts.Add($role)
    $fileProperty = $role + "SqlFile"
    $ownershipProperty = $role + "SqlOwnedByWorker"
    if (-not [bool]$state.$ownershipProperty) { $state.$fileProperty = $null }
  }
  return [pscustomobject]@{ State = $state; RemovalAttempts = @($removalAttempts); ProcessLaunched = $false }
}

function Get-AdvisoryPairObservationSql {
  param(
    [Parameter(Mandatory = $true)][string]$HolderApplicationName,
    [Parameter(Mandatory = $true)][string]$WaiterApplicationName,
    [switch]$RequireWaiterActivitiesRelationLock,
    [int]$ExpectedHolderBackendPid = 0,
    [int]$ExpectedWaiterBackendPid = 0,
    [AllowNull()][string]$TemporaryAssignmentId,
    [switch]$RequireTemporaryAssignmentAbsent
  )
  foreach ($applicationName in @($HolderApplicationName, $WaiterApplicationName)) {
    Assert-Condition -Condition ($applicationName -cmatch '^sitaa_sem01_[a-z0-9_]{1,48}$') -Code "advisory_pair_application_name_rejected" -FailureClass "source_integrity_rejection"
  }
  Assert-Condition -Condition ($ExpectedHolderBackendPid -ge 0 -and $ExpectedWaiterBackendPid -ge 0) -Code "advisory_pair_expected_pid_rejected" -FailureClass "source_integrity_rejection"
  if ($RequireTemporaryAssignmentAbsent) {
    Assert-Condition -Condition ($TemporaryAssignmentId -cmatch '^[0-9a-f-]{36}$') -Code "advisory_pair_assignment_id_rejected" -FailureClass "source_integrity_rejection"
  }
  $relationRequired = if ($RequireWaiterActivitiesRelationLock) { "true" } else { "false" }
  $expectedHolderMatch = if ($ExpectedHolderBackendPid -gt 0) { "exists (select 1 from holder_sessions where pid = $ExpectedHolderBackendPid)" } else { "true" }
  $expectedWaiterMatch = if ($ExpectedWaiterBackendPid -gt 0) { "exists (select 1 from waiter_sessions where pid = $ExpectedWaiterBackendPid)" } else { "true" }
  $assignmentAbsent = if ($RequireTemporaryAssignmentAbsent) {
    "not exists (select 1 from public.role_assignments where id = '$TemporaryAssignmentId'::uuid)"
  }
  else { "true" }
  return @"
begin; set transaction read only;
with holder_sessions as (
  select activity.pid, activity.state, activity.backend_type
  from pg_catalog.pg_stat_activity activity
  where activity.application_name = '$HolderApplicationName'
), waiter_sessions as (
  select activity.pid, activity.state, activity.backend_type
  from pg_catalog.pg_stat_activity activity
  where activity.application_name = '$WaiterApplicationName'
), pair_state as (
  select
    (select count(*) from holder_sessions) as exact_holder_count,
    (select count(*) from waiter_sessions) as exact_waiter_count,
    1 = (
      select count(*) from holder_sessions session_info
      join pg_catalog.pg_locks lock_info on lock_info.pid = session_info.pid
      where lock_info.locktype = 'advisory' and lock_info.classid = $($script:Sem01AdvisoryKeyOne)
        and lock_info.objid = $($script:Sem01AdvisoryKeyTwo) and lock_info.objsubid = $($script:Sem01AdvisoryObjSubId)
        and lock_info.granted
    ) as holder_advisory_granted,
    1 = (
      select count(*) from waiter_sessions session_info
      join pg_catalog.pg_locks lock_info on lock_info.pid = session_info.pid
      where lock_info.locktype = 'advisory' and lock_info.classid = $($script:Sem01AdvisoryKeyOne)
        and lock_info.objid = $($script:Sem01AdvisoryKeyTwo) and lock_info.objsubid = $($script:Sem01AdvisoryObjSubId)
        and not lock_info.granted
    ) as waiter_advisory_ungranted,
    exists (select 1 from holder_sessions where state is not null and backend_type = 'client backend') as holder_alive,
    exists (select 1 from waiter_sessions where state is not null and backend_type = 'client backend') as waiter_alive,
    coalesce((select holder.pid <> waiter.pid from holder_sessions holder cross join waiter_sessions waiter limit 1), false) as pids_differ,
    exists (
      select 1 from waiter_sessions session_info
      join pg_catalog.pg_locks lock_info on lock_info.pid = session_info.pid
      where lock_info.relation = 'public.activities'::regclass
        and lock_info.mode = 'RowExclusiveLock' and lock_info.granted
    ) as waiter_activities_row_exclusive_granted,
    not exists (
      select 1 from holder_sessions session_info
      join pg_catalog.pg_locks lock_info on lock_info.pid = session_info.pid
      where lock_info.relation = 'public.activities'::regclass
        and lock_info.mode in ('ShareLock', 'ShareRowExclusiveLock', 'ExclusiveLock', 'AccessExclusiveLock')
    ) as holder_activities_conflict_absent,
    $expectedHolderMatch as expected_holder_matched,
    $expectedWaiterMatch as expected_waiter_matched,
    $assignmentAbsent as temporary_assignment_absent,
    coalesce((select pid from holder_sessions limit 1), 0) as internal_holder_pid,
    coalesce((select pid from waiter_sessions limit 1), 0) as internal_waiter_pid
), accepted as (
  select *,
    exact_holder_count = 1 and exact_waiter_count = 1 and holder_advisory_granted and waiter_advisory_ungranted
      and holder_alive and waiter_alive and pids_differ and expected_holder_matched and expected_waiter_matched
      and (not $relationRequired or (waiter_activities_row_exclusive_granted and holder_activities_conflict_absent))
      and temporary_assignment_absent as satisfied
  from pair_state
)
select 'ADVISORY_PAIR_STATE|' || satisfied::int || '|' || exact_holder_count || '|' || exact_waiter_count ||
  '|' || holder_advisory_granted::int || '|' || waiter_advisory_ungranted::int ||
  '|' || holder_alive::int || '|' || waiter_alive::int || '|' || pids_differ::int ||
  '|' || waiter_activities_row_exclusive_granted::int || '|' || holder_activities_conflict_absent::int ||
  '|' || expected_holder_matched::int || '|' || expected_waiter_matched::int || '|' || temporary_assignment_absent::int ||
  '|' || internal_holder_pid || '|' || internal_waiter_pid
from accepted;
rollback;
"@
}

function ConvertFrom-AdvisoryPairObservation {
  param([Parameter(Mandatory = $true)][object]$Result)
  $state = Get-MarkerParts -Result $Result -Marker "ADVISORY_PAIR_STATE"
  Assert-Condition -Condition ($state.Count -eq 16) -Code "advisory_pair_marker_shape_rejected"
  return [pscustomobject]@{
    Satisfied = ($state[1] -ceq "1")
    ExactHolderCount = [int]$state[2]
    ExactWaiterCount = [int]$state[3]
    HolderAdvisoryGranted = ($state[4] -ceq "1")
    WaiterAdvisoryUnGranted = ($state[5] -ceq "1")
    HolderAlive = ($state[6] -ceq "1")
    WaiterAlive = ($state[7] -ceq "1")
    HolderWaiterPidsDiffer = ($state[8] -ceq "1")
    WaiterActivitiesRowExclusiveGranted = ($state[9] -ceq "1")
    HolderActivitiesConflictAbsent = ($state[10] -ceq "1")
    ExpectedHolderMatched = ($state[11] -ceq "1")
    ExpectedWaiterMatched = ($state[12] -ceq "1")
    TemporaryAssignmentAbsent = ($state[13] -ceq "1")
    InternalHolderBackendPid = [int]$state[14]
    InternalWaiterBackendPid = [int]$state[15]
  }
}

function Test-ExactAdvisoryPairEvidence {
  param(
    [Parameter(Mandatory = $true)][object]$Evidence,
    [switch]$RequireWaiterActivitiesRelationLock,
    [switch]$RequireTemporaryAssignmentAbsent
  )
  $core = ($Evidence.ExactHolderCount -eq 1 -and $Evidence.ExactWaiterCount -eq 1 -and
    $Evidence.HolderAdvisoryGranted -and $Evidence.WaiterAdvisoryUnGranted -and
    $Evidence.HolderAlive -and $Evidence.WaiterAlive -and $Evidence.HolderWaiterPidsDiffer -and
    $Evidence.InternalHolderBackendPid -gt 0 -and $Evidence.InternalWaiterBackendPid -gt 0 -and
    $Evidence.InternalHolderBackendPid -ne $Evidence.InternalWaiterBackendPid -and
    $Evidence.ExpectedHolderMatched -and $Evidence.ExpectedWaiterMatched)
  $relation = (-not $RequireWaiterActivitiesRelationLock -or
    ($Evidence.WaiterActivitiesRowExclusiveGranted -and $Evidence.HolderActivitiesConflictAbsent))
  $assignment = (-not $RequireTemporaryAssignmentAbsent -or $Evidence.TemporaryAssignmentAbsent)
  return [bool]($core -and $relation -and $assignment)
}

function ConvertTo-SanitizedAdvisoryPairEvidence {
  param([Parameter(Mandatory = $true)][object]$Evidence)
  return [pscustomobject]@{
    ExactHolderCount = [int]$Evidence.ExactHolderCount
    ExactWaiterCount = [int]$Evidence.ExactWaiterCount
    HolderAdvisoryGranted = [bool]$Evidence.HolderAdvisoryGranted
    WaiterAdvisoryUnGranted = [bool]$Evidence.WaiterAdvisoryUnGranted
    HolderAlive = [bool]$Evidence.HolderAlive
    WaiterAlive = [bool]$Evidence.WaiterAlive
    HolderWaiterPidsDiffer = [bool]$Evidence.HolderWaiterPidsDiffer
    WaiterActivitiesRowExclusiveGranted = [bool]$Evidence.WaiterActivitiesRowExclusiveGranted
    HolderActivitiesConflictAbsent = [bool]$Evidence.HolderActivitiesConflictAbsent
    ExpectedHolderMatched = [bool]$Evidence.ExpectedHolderMatched
    ExpectedWaiterMatched = [bool]$Evidence.ExpectedWaiterMatched
    TemporaryAssignmentAbsent = [bool]$Evidence.TemporaryAssignmentAbsent
  }
}

function Invoke-AdvisoryPairObservationProbe {
  param(
    [Parameter(Mandatory = $true)][object]$Connection,
    [Parameter(Mandatory = $true)][string]$PsqlPath,
    [Parameter(Mandatory = $true)][string]$RunDirectory,
    [Parameter(Mandatory = $true)][string]$HolderApplicationName,
    [Parameter(Mandatory = $true)][string]$WaiterApplicationName,
    [Parameter(Mandatory = $true)][string]$ObserverApplicationName,
    [switch]$RequireWaiterActivitiesRelationLock,
    [int]$ExpectedHolderBackendPid = 0,
    [int]$ExpectedWaiterBackendPid = 0,
    [AllowNull()][string]$TemporaryAssignmentId,
    [switch]$RequireTemporaryAssignmentAbsent
  )
  $probeSql = Get-AdvisoryPairObservationSql -HolderApplicationName $HolderApplicationName -WaiterApplicationName $WaiterApplicationName `
    -RequireWaiterActivitiesRelationLock:$RequireWaiterActivitiesRelationLock -ExpectedHolderBackendPid $ExpectedHolderBackendPid `
    -ExpectedWaiterBackendPid $ExpectedWaiterBackendPid -TemporaryAssignmentId $TemporaryAssignmentId `
    -RequireTemporaryAssignmentAbsent:$RequireTemporaryAssignmentAbsent
  $probe = Invoke-PsqlSql -Connection $Connection -PsqlPath $PsqlPath -Sql $probeSql -ApplicationName $ObserverApplicationName `
    -RunDirectory $RunDirectory -StatementTimeoutMilliseconds $script:ObserverProbeCommandTimeoutMilliseconds `
    -LockTimeoutMilliseconds $script:ObserverProbeCommandTimeoutMilliseconds -ProcessTimeoutMilliseconds $script:ObserverProbeProcessTimeoutMilliseconds
  if ($probe.ExitCode -ne 0 -or $probe.TimedOut) {
    Throw-StableFailure -Code "observer_probe_failed" -FailureClass "worker_crash"
  }
  $evidence = ConvertFrom-AdvisoryPairObservation -Result $probe
  $satisfied = Test-ExactAdvisoryPairEvidence -Evidence $evidence -RequireWaiterActivitiesRelationLock:$RequireWaiterActivitiesRelationLock `
    -RequireTemporaryAssignmentAbsent:$RequireTemporaryAssignmentAbsent
  Assert-Condition -Condition ($satisfied -eq [bool]$evidence.Satisfied) -Code "advisory_pair_marker_decision_rejected" -FailureClass "source_integrity_rejection"
  return [pscustomobject]@{ Satisfied = $satisfied; Evidence = $evidence }
}

function Invoke-AdvisoryWaitPair {
  param(
    [Parameter(Mandatory = $true)][object]$Connection,
    [Parameter(Mandatory = $true)][string]$PsqlPath,
    [Parameter(Mandatory = $true)][string]$RunDirectory,
    [Parameter(Mandatory = $true)][string]$HolderStageASql,
    [Parameter(Mandatory = $true)][string]$WaiterSql,
    [Parameter(Mandatory = $true)][string]$Label,
    [Parameter(Mandatory = $true)][string]$HolderReadyMarker,
    [Parameter(Mandatory = $true)][string]$HolderReleaseMarker,
    [switch]$RequireWaiterActivitiesRelationLock,
    [switch]$WaitForExpected55P03BeforeRelease
  )
  $pairResources = New-PairedTransientSqlOwnershipState
  $pairResult = $null
  $pairError = $null
  $pairScenario = $null
  $waiterStartCount = 0
  $holderApplicationName = "sitaa_sem01_" + $Label + "_holder"
  $waiterApplicationName = "sitaa_sem01_" + $Label + "_waiter"
  try {
    $holderArtifact = New-SqlFile -RunDirectory $RunDirectory -Label ($Label + "_holder") -Sql $HolderStageASql -InitialOwner controller
    $pairResources.HolderSqlFile = $holderArtifact.Path
    $pairResources.HolderOwnershipState = $holderArtifact.OwnershipState
    $waiterArtifact = New-SqlFile -RunDirectory $RunDirectory -Label ($Label + "_waiter") -Sql $WaiterSql -InitialOwner controller
    $pairResources.WaiterSqlFile = $waiterArtifact.Path
    $pairResources.WaiterOwnershipState = $waiterArtifact.OwnershipState
    $pairResources.HolderWorker = Start-StagedRuntimeAdvisoryHolder -Connection $Connection -PsqlPath $PsqlPath -RunDirectory $RunDirectory `
      -SqlFile $pairResources.HolderSqlFile -DisposableSqlOwnershipState $pairResources.HolderOwnershipState `
      -ApplicationName $holderApplicationName -ReadyMarker $HolderReadyMarker -ReleaseMarker $HolderReleaseMarker
    Set-TransientSqlWorkerOwnership -State $pairResources -Role "Holder" -Worker $pairResources.HolderWorker -OwnedByWorker $true
    $holderStageARequest = Send-StagedRuntimeAdvisoryHolderStage -Worker $pairResources.HolderWorker -Stage "A"
    $holderReadyObservation = Wait-StagedRuntimeAdvisoryHolderMarker -Worker $pairResources.HolderWorker -Marker $HolderReadyMarker -StageRequest $holderStageARequest
    $holderReadyMarkerObserved = [string]$holderReadyObservation.Value -ceq "1"
    $holderReadyMarkerWithinDeadline = $holderReadyMarkerObserved -and
      [double]$holderReadyObservation.CommandElapsedMilliseconds -ge 0 -and
      [double]$holderReadyObservation.CommandElapsedMilliseconds -le $script:ObserverTimeoutMilliseconds
    Assert-Condition -Condition ($holderReadyMarkerObserved -and $holderReadyMarkerWithinDeadline) `
      -Code "staged_runtime_holder_ready_marker_deadline_rejected" -FailureClass "unexpected_timeout"
    $holderReadiness = Wait-ForExactAdvisoryHolder -Connection $Connection -PsqlPath $PsqlPath -RunDirectory $RunDirectory `
      -HolderApplicationName $holderApplicationName -ObserverApplicationName "sitaa_sem01_holder_observer" `
      -HolderWorker $pairResources.HolderWorker -WaiterStartCount $waiterStartCount
    $frozenHolderBackendPid = [int]$holderReadiness.Evidence.InternalHolderBackendPid
    $pairResources.WaiterWorker = Start-AdvisoryWaiterAfterHolderReady -HolderObservation $holderReadiness -WaiterStartCount ([ref]$waiterStartCount) -StartOperation {
      Start-PsqlWorker -Connection $Connection -PsqlPath $PsqlPath -SqlFile $pairResources.WaiterSqlFile -ApplicationName $waiterApplicationName -RunDirectory $RunDirectory -StatementTimeoutMilliseconds 60000 -LockTimeoutMilliseconds 30000 -DeleteSqlFileOnCompletion $true -DisposableSqlOwnershipState $pairResources.WaiterOwnershipState
    }
    Set-TransientSqlWorkerOwnership -State $pairResources -Role "Waiter" -Worker $pairResources.WaiterWorker -OwnedByWorker $true
    $observation = Wait-ForObserverCondition -FailureCode "advisory_wait_not_observed" -Probe {
      Invoke-AdvisoryPairObservationProbe -Connection $Connection -PsqlPath $PsqlPath -RunDirectory $RunDirectory `
        -HolderApplicationName $holderApplicationName -WaiterApplicationName $waiterApplicationName `
        -ObserverApplicationName "sitaa_sem01_pair_observer" -RequireWaiterActivitiesRelationLock:$RequireWaiterActivitiesRelationLock `
        -ExpectedHolderBackendPid $frozenHolderBackendPid
    }
    $sanitizedEvidence = ConvertTo-SanitizedAdvisoryPairEvidence -Evidence $observation.Evidence
    $sameHolderObservedInPair = Test-SameAdvisoryHolderObservedInPair -HolderObservation $holderReadiness -PairEvidence $observation.Evidence
    if ($holderReadiness.Satisfied -and $sameHolderObservedInPair -and $observation.Satisfied -and
      (Test-ExactAdvisoryPairEvidence -Evidence $observation.Evidence -RequireWaiterActivitiesRelationLock:$RequireWaiterActivitiesRelationLock)) {
      $script:AdvisoryObservationCount++
    }
    $waiterResult = $null
    $holderAliveBeforeRelease = Test-LocalPsqlWorkerAlive -Worker $pairResources.HolderWorker
    $waiterRejectedBeforeRelease = $false
    if ($WaitForExpected55P03BeforeRelease) {
      $waiterResult = Wait-PsqlWorker -Worker $pairResources.WaiterWorker -TimeoutMilliseconds 70000 -KeepRawLogs
      $pairResources.WaiterWorker = $null
      $pairResources.WaiterSqlOwnedByWorker = $false
      $pairResources.WaiterSqlFile = $null
      Assert-Condition -Condition (-not $waiterResult.TimedOut -and ($waiterResult.Stderr -notmatch '(?i)40P01|deadlock detected')) -Code "advisory_waiter_pre_release_collection_rejected"
      Assert-ExpectedSqlState -Result $waiterResult -SqlState "55P03" -MessagePattern "lock timeout|could not obtain lock" -FailureCode "advisory_waiter_expected_55P03_missing"
      $waiterRejectedBeforeRelease = $true
      Assert-Condition -Condition (Test-LocalPsqlWorkerAlive -Worker $pairResources.HolderWorker) -Code "staged_runtime_holder_not_alive_after_waiter_rejection"
    }
    $holderStageBRequest = Send-StagedRuntimeAdvisoryHolderStage -Worker $pairResources.HolderWorker -Stage "B"
    $holderReleaseObservation = Wait-StagedRuntimeAdvisoryHolderMarker -Worker $pairResources.HolderWorker -Marker $HolderReleaseMarker -StageRequest $holderStageBRequest
    $holderReleaseMarkerObserved = [string]$holderReleaseObservation.Value -ceq "1"
    $holderReleaseMarkerWithinDeadline = $holderReleaseMarkerObserved -and
      [double]$holderReleaseObservation.CommandElapsedMilliseconds -ge 0 -and
      [double]$holderReleaseObservation.CommandElapsedMilliseconds -le $script:ObserverTimeoutMilliseconds
    Assert-Condition -Condition ($holderReleaseMarkerObserved -and $holderReleaseMarkerWithinDeadline) `
      -Code "staged_runtime_holder_release_marker_deadline_rejected" -FailureClass "unexpected_timeout"
    $holderResult = Wait-StagedInstallationHolder -Worker $pairResources.HolderWorker -TimeoutMilliseconds 70000 -KeepRawLogs
    Remove-DisposableWorkerSqlFile -Worker $pairResources.HolderWorker
    Complete-PsqlDisposableWorkerOwnership -State $pairResources.HolderWorker.DisposableSqlOwnershipState
    $pairResources.HolderWorker = $null
    $pairResources.HolderSqlOwnedByWorker = $false
    $pairResources.HolderSqlFile = $null
    if (-not $WaitForExpected55P03BeforeRelease) {
      $waiterResult = Wait-PsqlWorker -Worker $pairResources.WaiterWorker -TimeoutMilliseconds 70000 -KeepRawLogs
      $pairResources.WaiterWorker = $null
      $pairResources.WaiterSqlOwnedByWorker = $false
      $pairResources.WaiterSqlFile = $null
    }
    if (($holderResult.Stderr + $waiterResult.Stderr) -match '(?i)40P01|deadlock detected') {
      Throw-StableFailure -Code "postgres_deadlock_40P01" -FailureClass "postgres_deadlock"
    }
    if ($holderResult.TimedOut -or $waiterResult.TimedOut) {
      Throw-StableFailure -Code "unexpected_timeout" -FailureClass "unexpected_timeout"
    }
    $pairResult = [pscustomobject]@{
      Holder = $holderResult
      Waiter = $waiterResult
      HolderOperationReadyMarkerObserved = $holderReadyMarkerObserved
      HolderReadyMarkerObserved = $holderReadyMarkerObserved
      HolderReadyMarkerWithinDeadline = $holderReadyMarkerWithinDeadline
      HolderReleaseMarkerObserved = $holderReleaseMarkerObserved
      HolderReleaseMarkerWithinDeadline = $holderReleaseMarkerWithinDeadline
      HolderAliveBeforeRelease = $holderAliveBeforeRelease
      WaiterRejectedBeforeHolderRelease = $waiterRejectedBeforeRelease
      HolderReleasedAfterExactPair = (-not $WaitForExpected55P03BeforeRelease -and [string]$holderReleaseObservation.Value -ceq "1")
      HolderReleasedAfterExpectedWaiterRejection = ($WaitForExpected55P03BeforeRelease -and $waiterRejectedBeforeRelease -and [string]$holderReleaseObservation.Value -ceq "1")
      HolderReadyBeforeWaiterStart = ($holderReadiness.Satisfied -and $waiterStartCount -eq 1)
      SameHolderObservedInPair = $sameHolderObservedInPair
      WaitObserved = [bool]$observation.Satisfied
      ExactHolderAndWaiterSessionsObserved = ($sanitizedEvidence.ExactHolderCount -eq 1 -and $sanitizedEvidence.ExactWaiterCount -eq 1)
      GrantedHolderAndUngrantedWaiterObserved = ($sanitizedEvidence.HolderAdvisoryGranted -and $sanitizedEvidence.WaiterAdvisoryUnGranted)
      RelationLockObserved = [bool](-not $RequireWaiterActivitiesRelationLock -or
        ($sanitizedEvidence.WaiterActivitiesRowExclusiveGranted -and $sanitizedEvidence.HolderActivitiesConflictAbsent))
      ExactHolderCount = $sanitizedEvidence.ExactHolderCount
      ExactWaiterCount = $sanitizedEvidence.ExactWaiterCount
      HolderAdvisoryGranted = $sanitizedEvidence.HolderAdvisoryGranted
      WaiterAdvisoryUnGranted = $sanitizedEvidence.WaiterAdvisoryUnGranted
      HolderAlive = $sanitizedEvidence.HolderAlive
      WaiterAlive = $sanitizedEvidence.WaiterAlive
      HolderWaiterPidsDiffer = $sanitizedEvidence.HolderWaiterPidsDiffer
      WaiterActivitiesRowExclusiveGranted = $sanitizedEvidence.WaiterActivitiesRowExclusiveGranted
      HolderActivitiesConflictAbsent = $sanitizedEvidence.HolderActivitiesConflictAbsent
    }
  }
  catch {
    $pairError = $_
    $pairScenario = [string]$script:CurrentScenario
  }
  $pairCleanup = Invoke-OrchestrationCleanup -EmitFailureMarkers -CleanupOperations @(
    [pscustomobject]@{ Name = "ADVISORY_HOLDER_STOP"; Operation = {
      if ($null -ne $pairResources.HolderWorker) {
        Stop-StagedRuntimeAdvisoryHolder -Worker $pairResources.HolderWorker
        $pairResources.HolderWorker = $null
        $pairResources.HolderSqlOwnedByWorker = $false
      }
    } },
    [pscustomobject]@{ Name = "ADVISORY_WAITER_STOP"; Operation = {
      if ($null -ne $pairResources.WaiterWorker) {
        Stop-PsqlWorker -Worker $pairResources.WaiterWorker
        $pairResources.WaiterWorker = $null
        $pairResources.WaiterSqlOwnedByWorker = $false
      }
    } },
    [pscustomobject]@{ Name = "ADVISORY_HOLDER_SQL_REMOVE"; Operation = {
      Remove-UnownedTransientSqlFile -State $pairResources -Role "Holder" -RunDirectory $RunDirectory
    } },
    [pscustomobject]@{ Name = "ADVISORY_WAITER_SQL_REMOVE"; Operation = {
      Remove-UnownedTransientSqlFile -State $pairResources -Role "Waiter" -RunDirectory $RunDirectory
    } }
  )
  Complete-OrchestrationCleanup -PrimaryError $pairError -PrimaryScenario $pairScenario -CleanupResult $pairCleanup `
    -CleanupFailureCode "advisory_pair_cleanup_rejected"
  Assert-Condition -Condition ($null -ne $pairResult -and $null -eq $pairResources.HolderWorker -and $null -eq $pairResources.WaiterWorker -and
    $null -eq $pairResources.HolderSqlFile -and $null -eq $pairResources.WaiterSqlFile) `
    -Code "advisory_pair_collection_postcondition_rejected"
  return $pairResult
}

function Get-CalendarCorrectionHolderStageASql {
  param(
    [Parameter(Mandatory = $true)][string]$AuthorityId,
    [Parameter(Mandatory = $true)][string]$Marker,
    [Parameter(Mandatory = $true)][string]$ReadyMarker
  )
  return @"
begin;
select set_config('request.jwt.claim.sub', '$AuthorityId', true);
set local role authenticated;
with target as (
  select * from public.academic_periods where is_active and code <> 'pilot' order by starts_on limit 1
), changed as (
  select * from public.correct_admin_academic_period(
    (select id from target), (select name || ' LAB' from target),
    (select starts_on from target), (select ends_on from target), 'Corrección sintética multisesión'
  )
)
select '$Marker|' || count(*) from changed;
select '$ReadyMarker|1';
"@
}

function Invoke-CalendarConcurrencyScenarios {
  param(
    [Parameter(Mandatory = $true)][object]$Connection,
    [Parameter(Mandatory = $true)][string]$PsqlPath,
    [Parameter(Mandatory = $true)][object]$Paths,
    [Parameter(Mandatory = $true)][object]$Manifest,
    [Parameter(Mandatory = $true)][System.Collections.ArrayList]$ApprovedResults,
    [Parameter(Mandatory = $true)][string]$AuthorityId,
    [Parameter(Mandatory = $true)][int]$ExpectedActivities
  )
  Set-CurrentScenario -ScenarioId "MS11_OVERLAPPING_CREATIONS"
  $holder = @"
begin;
select set_config('request.jwt.claim.sub', '$AuthorityId', true);
set local role authenticated;
select * from public.create_admin_academic_period('2098-1', date '2098-02-01', date '2098-05-31', true);
select 'MS11_WINNER_RPC|1';
select 'MS11_HOLDER_OPERATION_READY|1';
"@
  $waiter = @"
begin;
set local lock_timeout = '3s';
select set_config('request.jwt.claim.sub', '$AuthorityId', true);
set local role authenticated;
select * from public.create_admin_academic_period('2098-2', date '2098-03-01', date '2098-06-30', true);
rollback;
"@
  $pair = Invoke-AdvisoryWaitPair -Connection $Connection -PsqlPath $PsqlPath -RunDirectory $Paths.Root -HolderStageASql $holder -WaiterSql $waiter -Label "ms11_overlap" `
    -HolderReadyMarker "MS11_HOLDER_OPERATION_READY" -HolderReleaseMarker "MS11_HOLDER_RELEASED" -WaitForExpected55P03BeforeRelease
  Assert-Condition -Condition ($pair.WaitObserved) -Code "overlap_wait_not_observed"
  Assert-PsqlApproved -Result $pair.Holder -FailureCode "ms11_winner_rejected"
  Assert-ExpectedSqlState -Result $pair.Waiter -SqlState "55P03" -MessagePattern "lock timeout|could not obtain lock" -FailureCode "ms11_loser_contract_rejected"
  $ms11Marker = Get-MarkerParts -Result $pair.Holder -Marker "MS11_WINNER_RPC"
  $after11 = Assert-NoRuntimeResidue -Connection $Connection -PsqlPath $PsqlPath -RunDirectory $Paths.Root -ExpectedActivities $ExpectedActivities
  $script:DeterministicOutcomeCount++
  $ms11 = New-ScenarioResult -ScenarioId "MS11_OVERLAPPING_CREATIONS" -Outcome "winner_plus_expected_55P03" -Assertions ([ordered]@{
    WinnerRpcSucceededInTransaction = ($ms11Marker[1] -eq "1")
    HolderReadyBeforeWaiterStart = $pair.HolderReadyBeforeWaiterStart
    SameHolderObservedInPair = $pair.SameHolderObservedInPair
    CompetingSessionWaitObserved = $pair.WaitObserved
    ExactHolderAndWaiterSessionsObserved = ($pair.ExactHolderCount -eq 1 -and $pair.ExactWaiterCount -eq 1)
    GrantedHolderAndUngrantedWaiterObserved = ($pair.HolderAdvisoryGranted -and $pair.WaiterAdvisoryUnGranted)
    HolderAndWaiterAlive = ($pair.HolderAlive -and $pair.WaiterAlive -and $pair.HolderWaiterPidsDiffer)
    HolderOperationReadyMarkerObserved = $pair.HolderOperationReadyMarkerObserved
    HolderReadyMarkerObserved = $pair.HolderReadyMarkerObserved
    HolderReadyMarkerWithinDeadline = $pair.HolderReadyMarkerWithinDeadline
    HolderReleaseMarkerObserved = $pair.HolderReleaseMarkerObserved
    HolderReleaseMarkerWithinDeadline = $pair.HolderReleaseMarkerWithinDeadline
    HolderReleasedAfterExpectedWaiterRejection = $pair.HolderReleasedAfterExpectedWaiterRejection
    LoserRejected55P03 = $true
    WinnerRolledBackWithoutResidue = ($after11.FixturePeriods -eq 0 -and $after11.AuditEvents -eq 0)
  })
  Approve-ScenarioResult -ApprovedResults $ApprovedResults -Manifest $Manifest -Paths $Paths -Result $ms11

  Set-CurrentScenario -ScenarioId "MS12_CREATE_VERSUS_CORRECTION"
  $holderCorrection = @"
begin;
select set_config('request.jwt.claim.sub', '$AuthorityId', true);
set local role authenticated;
with target as (
  select * from public.academic_periods where is_active and code <> 'pilot' order by starts_on limit 1
), changed as (
  select * from public.correct_admin_academic_period(
    (select id from target), (select name || ' LAB' from target),
    (select starts_on from target), (select ends_on from target), 'Corrección sintética multisesión'
  )
)
select 'MS12_CORRECTION_RPC|' || count(*) from changed;
select 'MS12_HOLDER_OPERATION_READY|1';
"@
  $waiterCreate = @"
begin;
set local lock_timeout = '3s';
select set_config('request.jwt.claim.sub', '$AuthorityId', true);
set local role authenticated;
select * from public.create_admin_academic_period('2099-1', date '2098-08-01', date '2098-11-30', true);
rollback;
"@
  $pairTwo = Invoke-AdvisoryWaitPair -Connection $Connection -PsqlPath $PsqlPath -RunDirectory $Paths.Root -HolderStageASql $holderCorrection -WaiterSql $waiterCreate -Label "ms12_correct" `
    -HolderReadyMarker "MS12_HOLDER_OPERATION_READY" -HolderReleaseMarker "MS12_HOLDER_RELEASED" -WaitForExpected55P03BeforeRelease
  Assert-Condition -Condition ($pairTwo.WaitObserved) -Code "create_correction_wait_not_observed"
  Assert-PsqlApproved -Result $pairTwo.Holder -FailureCode "ms12_correction_rejected"
  Assert-ExpectedSqlState -Result $pairTwo.Waiter -SqlState "55P03" -MessagePattern "lock timeout|could not obtain lock" -FailureCode "ms12_create_lock_rejection_missing"
  $ms12Marker = Get-MarkerParts -Result $pairTwo.Holder -Marker "MS12_CORRECTION_RPC"
  $after12 = Assert-NoRuntimeResidue -Connection $Connection -PsqlPath $PsqlPath -RunDirectory $Paths.Root -ExpectedActivities $ExpectedActivities
  $script:DeterministicOutcomeCount++
  $ms12 = New-ScenarioResult -ScenarioId "MS12_CREATE_VERSUS_CORRECTION" -Outcome "correction_winner_plus_expected_55P03" -Assertions ([ordered]@{
    ValidCorrectionSucceededInTransaction = ($ms12Marker[1] -eq "1")
    HolderReadyBeforeWaiterStart = $pairTwo.HolderReadyBeforeWaiterStart
    SameHolderObservedInPair = $pairTwo.SameHolderObservedInPair
    RealAdvisoryWaitObserved = $pairTwo.WaitObserved
    ExactHolderAndWaiterSessionsObserved = ($pairTwo.ExactHolderCount -eq 1 -and $pairTwo.ExactWaiterCount -eq 1)
    GrantedHolderAndUngrantedWaiterObserved = ($pairTwo.HolderAdvisoryGranted -and $pairTwo.WaiterAdvisoryUnGranted)
    HolderAndWaiterAlive = ($pairTwo.HolderAlive -and $pairTwo.WaiterAlive -and $pairTwo.HolderWaiterPidsDiffer)
    HolderOperationReadyMarkerObserved = $pairTwo.HolderOperationReadyMarkerObserved
    HolderReadyMarkerObserved = $pairTwo.HolderReadyMarkerObserved
    HolderReadyMarkerWithinDeadline = $pairTwo.HolderReadyMarkerWithinDeadline
    HolderReleaseMarkerObserved = $pairTwo.HolderReleaseMarkerObserved
    HolderReleaseMarkerWithinDeadline = $pairTwo.HolderReleaseMarkerWithinDeadline
    HolderReleasedAfterExpectedWaiterRejection = $pairTwo.HolderReleasedAfterExpectedWaiterRejection
    CompetingCreateRejected55P03 = $true
    SuccessfulFixtureRolledBack = ($after12.FixturePeriods -eq 0 -and $after12.AuditEvents -eq 0)
  })
  Approve-ScenarioResult -ApprovedResults $ApprovedResults -Manifest $Manifest -Paths $Paths -Result $ms12
}

function Invoke-ActivityConcurrencyScenarios {
  param(
    [Parameter(Mandatory = $true)][object]$Connection,
    [Parameter(Mandatory = $true)][string]$PsqlPath,
    [Parameter(Mandatory = $true)][object]$Paths,
    [Parameter(Mandatory = $true)][object]$Manifest,
    [Parameter(Mandatory = $true)][System.Collections.ArrayList]$ApprovedResults,
    [Parameter(Mandatory = $true)][string]$AuthorityId,
    [Parameter(Mandatory = $true)][string]$ActivityId
  )
  Set-CurrentScenario -ScenarioId "MS13_PUBLISH_VERSUS_CALENDAR"
  $ms13Holder = Get-CalendarCorrectionHolderStageASql -AuthorityId $AuthorityId -Marker "MS13_CALENDAR_RPC" -ReadyMarker "MS13_HOLDER_OPERATION_READY"
  $ms13Waiter = @"
begin;
select set_config('request.jwt.claim.sub', '$AuthorityId', true);
set local role authenticated;
with published as (
  select * from public.publish_activity('$ActivityId'::uuid)
), resolved as (
  select p.id from public.activities a cross join lateral public.get_academic_period_for_date(a.start_date) p
  where a.id = '$ActivityId'::uuid
)
select 'MS13_PUBLISH_RESULT|' || published.academic_period_id || '|' || resolved.id
from published cross join resolved;
rollback;
"@
  $ms13Pair = Invoke-AdvisoryWaitPair -Connection $Connection -PsqlPath $PsqlPath -RunDirectory $Paths.Root -HolderStageASql $ms13Holder -WaiterSql $ms13Waiter -Label "ms13_publish" `
    -HolderReadyMarker "MS13_HOLDER_OPERATION_READY" -HolderReleaseMarker "MS13_HOLDER_RELEASED"
  Assert-PsqlApproved -Result $ms13Pair.Holder -FailureCode "ms13_calendar_holder_rejected"
  Assert-PsqlApproved -Result $ms13Pair.Waiter -FailureCode "ms13_publish_rejected"
  $ms13Marker = Get-MarkerParts -Result $ms13Pair.Waiter -Marker "MS13_PUBLISH_RESULT"
  $resolverSql = @"
begin; set transaction read only;
select 'INDEPENDENT_RESOLVER|' || p.id
from public.activities a cross join lateral public.get_academic_period_for_date(a.start_date) p
where a.id = '$ActivityId'::uuid;
rollback;
"@
  $resolverResult = Invoke-PsqlSql -Connection $Connection -PsqlPath $PsqlPath -Sql $resolverSql -ApplicationName "sitaa_sem01_ms13_resolver" -RunDirectory $Paths.Root
  Assert-PsqlApproved -Result $resolverResult -FailureCode "ms13_resolver_rejected"
  $resolverMarker = Get-MarkerParts -Result $resolverResult -Marker "INDEPENDENT_RESOLVER"
  $script:DeterministicOutcomeCount++
  $ms13 = New-ScenarioResult -ScenarioId "MS13_PUBLISH_VERSUS_CALENDAR" -Outcome "serialized_publish_reresolved" -Assertions ([ordered]@{
    HolderReadyMarkerObserved = $ms13Pair.HolderReadyMarkerObserved
    HolderReadyMarkerWithinDeadline = $ms13Pair.HolderReadyMarkerWithinDeadline
    HolderReleaseMarkerObserved = $ms13Pair.HolderReleaseMarkerObserved
    HolderReleaseMarkerWithinDeadline = $ms13Pair.HolderReleaseMarkerWithinDeadline
    CalendarMutationReachedSuccess = ((Get-MarkerParts -Result $ms13Pair.Holder -Marker "MS13_CALENDAR_RPC")[1] -eq "1")
    HolderReadyBeforeWaiterStart = $ms13Pair.HolderReadyBeforeWaiterStart
    SameHolderObservedInPair = $ms13Pair.SameHolderObservedInPair
    PublicationAdvisoryWaitObserved = $ms13Pair.WaitObserved
    ExactHolderAndWaiterSessionsObserved = ($ms13Pair.ExactHolderCount -eq 1 -and $ms13Pair.ExactWaiterCount -eq 1)
    GrantedHolderAndUngrantedWaiterObserved = ($ms13Pair.HolderAdvisoryGranted -and $ms13Pair.WaiterAdvisoryUnGranted)
    HolderAndWaiterAlive = ($ms13Pair.HolderAlive -and $ms13Pair.WaiterAlive -and $ms13Pair.HolderWaiterPidsDiffer)
    HolderReleasedAfterExactPair = $ms13Pair.HolderReleasedAfterExactPair
    PublishReturnedResolverValue = ($ms13Marker[1] -eq $ms13Marker[2])
    IndependentResolverMatches = ($ms13Marker[1] -eq $resolverMarker[1])
    PublicationRolledBack = ((Assert-NoRuntimeResidue -Connection $Connection -PsqlPath $PsqlPath -RunDirectory $Paths.Root -ExpectedActivities 1).Activities -eq 1)
  })
  Approve-ScenarioResult -ApprovedResults $ApprovedResults -Manifest $Manifest -Paths $Paths -Result $ms13

  Set-CurrentScenario -ScenarioId "MS14_ACTIVITY_DATE_VERSUS_CALENDAR"
  $ms14Holder = Get-CalendarCorrectionHolderStageASql -AuthorityId $AuthorityId -Marker "MS14_CALENDAR_RPC" -ReadyMarker "MS14_HOLDER_OPERATION_READY"
  $ms14Waiter = @"
begin;
select set_config('request.jwt.claim.sub', '$AuthorityId', true);
set local role authenticated;
with current_row as (
  select * from public.activities where id = '$ActivityId'::uuid
), resolved as (
  select p.id from current_row a cross join lateral public.get_academic_period_for_date(a.start_date + 1) p
), changed as (
  update public.activities a
  set start_date = a.start_date + 1,
      end_date = a.end_date + 1,
      academic_period_id = resolved.id,
      status_code = 'scheduled'
  from resolved
  where a.id = '$ActivityId'::uuid
  returning a.academic_period_id, a.start_date
)
select 'MS14_DATE_RESULT|' || changed.academic_period_id || '|' || resolved.id
from changed cross join resolved;
rollback;
"@
  $ms14Pair = Invoke-AdvisoryWaitPair -Connection $Connection -PsqlPath $PsqlPath -RunDirectory $Paths.Root -HolderStageASql $ms14Holder -WaiterSql $ms14Waiter -Label "ms14_date" `
    -HolderReadyMarker "MS14_HOLDER_OPERATION_READY" -HolderReleaseMarker "MS14_HOLDER_RELEASED" -RequireWaiterActivitiesRelationLock
  Assert-PsqlApproved -Result $ms14Pair.Holder -FailureCode "ms14_calendar_holder_rejected"
  Assert-PsqlApproved -Result $ms14Pair.Waiter -FailureCode "ms14_activity_update_rejected"
  $ms14Marker = Get-MarkerParts -Result $ms14Pair.Waiter -Marker "MS14_DATE_RESULT"
  $script:DeterministicOutcomeCount++
  $ms14 = New-ScenarioResult -ScenarioId "MS14_ACTIVITY_DATE_VERSUS_CALENDAR" -Outcome "actual_start_date_update_reresolved" -Assertions ([ordered]@{
    HolderReadyMarkerObserved = $ms14Pair.HolderReadyMarkerObserved
    HolderReadyMarkerWithinDeadline = $ms14Pair.HolderReadyMarkerWithinDeadline
    HolderReleaseMarkerObserved = $ms14Pair.HolderReleaseMarkerObserved
    HolderReleaseMarkerWithinDeadline = $ms14Pair.HolderReleaseMarkerWithinDeadline
    ActualStartDateUpdateExecuted = ($ms14Marker.Count -eq 3)
    HolderReadyBeforeWaiterStart = $ms14Pair.HolderReadyBeforeWaiterStart
    SameHolderObservedInPair = $ms14Pair.SameHolderObservedInPair
    AdvisoryWaitObserved = $ms14Pair.WaitObserved
    RelationLockObserved = $ms14Pair.RelationLockObserved
    ExactHolderAndWaiterSessionsObserved = ($ms14Pair.ExactHolderCount -eq 1 -and $ms14Pair.ExactWaiterCount -eq 1)
    GrantedHolderAndUngrantedWaiterObserved = ($ms14Pair.HolderAdvisoryGranted -and $ms14Pair.WaiterAdvisoryUnGranted)
    HolderAndWaiterAlive = ($ms14Pair.HolderAlive -and $ms14Pair.WaiterAlive -and $ms14Pair.HolderWaiterPidsDiffer)
    RelationEvidenceBoundToExactPair = ($ms14Pair.WaiterActivitiesRowExclusiveGranted -and $ms14Pair.HolderActivitiesConflictAbsent)
    HolderReleasedAfterExactPair = $ms14Pair.HolderReleasedAfterExactPair
    StoredFkEqualsCurrentResolver = ($ms14Marker[1] -eq $ms14Marker[2])
    UpdateRolledBack = ((Assert-NoRuntimeResidue -Connection $Connection -PsqlPath $PsqlPath -RunDirectory $Paths.Root -ExpectedActivities 1).Activities -eq 1)
  })
  Approve-ScenarioResult -ApprovedResults $ApprovedResults -Manifest $Manifest -Paths $Paths -Result $ms14

  Set-CurrentScenario -ScenarioId "MS15_ACTIVITY_RELATION_HOLDER_WAITS_ADVISORY"
  $ms15Holder = Get-CalendarCorrectionHolderStageASql -AuthorityId $AuthorityId -Marker "MS15_CALENDAR_RPC" -ReadyMarker "MS15_HOLDER_OPERATION_READY"
  $ms15Waiter = @"
begin;
select set_config('request.jwt.claim.sub', '$AuthorityId', true);
set local role authenticated;
with changed as (
  update public.activities set start_date = start_date where id = '$ActivityId'::uuid returning id
)
select 'MS15_ACTIVITY_STATEMENT|' || count(*) from changed;
rollback;
"@
  $ms15Pair = Invoke-AdvisoryWaitPair -Connection $Connection -PsqlPath $PsqlPath -RunDirectory $Paths.Root -HolderStageASql $ms15Holder -WaiterSql $ms15Waiter -Label "ms15_relation" `
    -HolderReadyMarker "MS15_HOLDER_OPERATION_READY" -HolderReleaseMarker "MS15_HOLDER_RELEASED" -RequireWaiterActivitiesRelationLock
  Assert-PsqlApproved -Result $ms15Pair.Holder -FailureCode "ms15_calendar_holder_rejected"
  Assert-PsqlApproved -Result $ms15Pair.Waiter -FailureCode "ms15_activity_statement_rejected"
  $ms15 = New-ScenarioResult -ScenarioId "MS15_ACTIVITY_RELATION_HOLDER_WAITS_ADVISORY" -Outcome "relation_lock_held_while_advisory_waited" -Assertions ([ordered]@{
    HolderReadyMarkerObserved = $ms15Pair.HolderReadyMarkerObserved
    HolderReadyMarkerWithinDeadline = $ms15Pair.HolderReadyMarkerWithinDeadline
    HolderReleaseMarkerObserved = $ms15Pair.HolderReleaseMarkerObserved
    HolderReleaseMarkerWithinDeadline = $ms15Pair.HolderReleaseMarkerWithinDeadline
    ActualActivityStatementExecuted = ((Get-MarkerParts -Result $ms15Pair.Waiter -Marker "MS15_ACTIVITY_STATEMENT")[1] -eq "1")
    RowExclusiveObserved = $ms15Pair.RelationLockObserved
    HolderReadyBeforeWaiterStart = $ms15Pair.HolderReadyBeforeWaiterStart
    SameHolderObservedInPair = $ms15Pair.SameHolderObservedInPair
    AdvisoryWaitObserved = $ms15Pair.WaitObserved
    CalendarHolderHadNoConflictingRelationWait = $ms15Pair.RelationLockObserved
    ExactHolderAndWaiterSessionsObserved = ($ms15Pair.ExactHolderCount -eq 1 -and $ms15Pair.ExactWaiterCount -eq 1)
    GrantedHolderAndUngrantedWaiterObserved = ($ms15Pair.HolderAdvisoryGranted -and $ms15Pair.WaiterAdvisoryUnGranted)
    HolderAndWaiterAlive = ($ms15Pair.HolderAlive -and $ms15Pair.WaiterAlive -and $ms15Pair.HolderWaiterPidsDiffer)
    RelationEvidenceBoundToExactPair = ($ms15Pair.WaiterActivitiesRowExclusiveGranted -and $ms15Pair.HolderActivitiesConflictAbsent)
    HolderReleasedAfterExactPair = $ms15Pair.HolderReleasedAfterExactPair
    NoDeadlock = (($ms15Pair.Holder.Stderr + $ms15Pair.Waiter.Stderr) -notmatch '(?i)40P01|deadlock detected')
  })
  $script:DeterministicOutcomeCount++
  Approve-ScenarioResult -ApprovedResults $ApprovedResults -Manifest $Manifest -Paths $Paths -Result $ms15

  Set-CurrentScenario -ScenarioId "MS16_CALENDAR_MUTATION_WAITS_ADVISORY"
  $ms16Holder = @"
begin;
select set_config('request.jwt.claim.sub', '$AuthorityId', true);
set local role authenticated;
with changed as (
  update public.activities set start_date = start_date where id = '$ActivityId'::uuid returning id
)
select 'MS16_ACTIVITY_HOLDER|' || count(*) from changed;
select 'MS16_HOLDER_OPERATION_READY|1';
"@
  $ms16Waiter = @"
begin;
select set_config('request.jwt.claim.sub', '$AuthorityId', true);
set local role authenticated;
with created as (
  select * from public.create_admin_academic_period('2099-2', date '2099-02-01', date '2099-05-31', true)
)
select 'MS16_CALENDAR_AFTER_WAIT|' || count(*) from created;
rollback;
"@
  $ms16Pair = Invoke-AdvisoryWaitPair -Connection $Connection -PsqlPath $PsqlPath -RunDirectory $Paths.Root -HolderStageASql $ms16Holder -WaiterSql $ms16Waiter -Label "ms16_reverse" `
    -HolderReadyMarker "MS16_HOLDER_OPERATION_READY" -HolderReleaseMarker "MS16_HOLDER_RELEASED"
  Assert-PsqlApproved -Result $ms16Pair.Holder -FailureCode "ms16_activity_holder_rejected"
  Assert-PsqlApproved -Result $ms16Pair.Waiter -FailureCode "ms16_calendar_waiter_rejected"
  $script:DeterministicOutcomeCount++
  $ms16 = New-ScenarioResult -ScenarioId "MS16_CALENDAR_MUTATION_WAITS_ADVISORY" -Outcome "calendar_rpc_serialized_after_activity" -Assertions ([ordered]@{
    HolderReadyMarkerObserved = $ms16Pair.HolderReadyMarkerObserved
    HolderReadyMarkerWithinDeadline = $ms16Pair.HolderReadyMarkerWithinDeadline
    HolderReleaseMarkerObserved = $ms16Pair.HolderReleaseMarkerObserved
    HolderReleaseMarkerWithinDeadline = $ms16Pair.HolderReleaseMarkerWithinDeadline
    RelevantActivityTransactionExecuted = ((Get-MarkerParts -Result $ms16Pair.Holder -Marker "MS16_ACTIVITY_HOLDER")[1] -eq "1")
    HolderReadyBeforeWaiterStart = $ms16Pair.HolderReadyBeforeWaiterStart
    SameHolderObservedInPair = $ms16Pair.SameHolderObservedInPair
    CalendarRpcAdvisoryWaitObserved = $ms16Pair.WaitObserved
    ExactHolderAndWaiterSessionsObserved = ($ms16Pair.ExactHolderCount -eq 1 -and $ms16Pair.ExactWaiterCount -eq 1)
    GrantedHolderAndUngrantedWaiterObserved = ($ms16Pair.HolderAdvisoryGranted -and $ms16Pair.WaiterAdvisoryUnGranted)
    HolderAndWaiterAlive = ($ms16Pair.HolderAlive -and $ms16Pair.WaiterAlive -and $ms16Pair.HolderWaiterPidsDiffer)
    HolderReleasedAfterExactPair = $ms16Pair.HolderReleasedAfterExactPair
    CalendarRpcCompletedAfterRelease = ((Get-MarkerParts -Result $ms16Pair.Waiter -Marker "MS16_CALENDAR_AFTER_WAIT")[1] -eq "1")
    FixturePeriodAndAuditRolledBack = ((Assert-NoRuntimeResidue -Connection $Connection -PsqlPath $PsqlPath -RunDirectory $Paths.Root -ExpectedActivities 1).FixturePeriods -eq 0)
  })
  Approve-ScenarioResult -ApprovedResults $ApprovedResults -Manifest $Manifest -Paths $Paths -Result $ms16

  Set-CurrentScenario -ScenarioId "MS17_POST_WAIT_RERESOLUTION"
  $ms17Holder = Get-CalendarCorrectionHolderStageASql -AuthorityId $AuthorityId -Marker "MS17_CALENDAR_RPC" -ReadyMarker "MS17_HOLDER_OPERATION_READY"
  $ms17Waiter = @"
begin;
select set_config('request.jwt.claim.sub', '$AuthorityId', true);
set local role authenticated;
select 'MS17_PREVIEW_NULL|' || case when academic_period_id is null then 1 else 0 end
from public.activities where id = '$ActivityId'::uuid;
with published as (
  select * from public.publish_activity('$ActivityId'::uuid)
), resolved as (
  select p.id from public.activities a cross join lateral public.get_academic_period_for_date(a.start_date) p
  where a.id = '$ActivityId'::uuid
)
select 'MS17_RERESOLVED|' || published.academic_period_id || '|' || resolved.id
from published cross join resolved;
rollback;
"@
  $ms17Pair = Invoke-AdvisoryWaitPair -Connection $Connection -PsqlPath $PsqlPath -RunDirectory $Paths.Root -HolderStageASql $ms17Holder -WaiterSql $ms17Waiter -Label "ms17_reresolve" `
    -HolderReadyMarker "MS17_HOLDER_OPERATION_READY" -HolderReleaseMarker "MS17_HOLDER_RELEASED"
  Assert-PsqlApproved -Result $ms17Pair.Holder -FailureCode "ms17_calendar_holder_rejected"
  Assert-PsqlApproved -Result $ms17Pair.Waiter -FailureCode "ms17_publish_rejected"
  $previewMarker = Get-MarkerParts -Result $ms17Pair.Waiter -Marker "MS17_PREVIEW_NULL"
  $reresolvedMarker = Get-MarkerParts -Result $ms17Pair.Waiter -Marker "MS17_RERESOLVED"
  $independentAfter17 = Invoke-PsqlSql -Connection $Connection -PsqlPath $PsqlPath -Sql $resolverSql -ApplicationName "sitaa_sem01_ms17_resolver" -RunDirectory $Paths.Root
  Assert-PsqlApproved -Result $independentAfter17 -FailureCode "ms17_independent_resolver_rejected"
  $independentMarker17 = Get-MarkerParts -Result $independentAfter17 -Marker "INDEPENDENT_RESOLVER"
  $ms17 = New-ScenarioResult -ScenarioId "MS17_POST_WAIT_RERESOLUTION" -Outcome "null_preview_ignored_after_real_wait" -Assertions ([ordered]@{
    HolderReadyMarkerObserved = $ms17Pair.HolderReadyMarkerObserved
    HolderReadyMarkerWithinDeadline = $ms17Pair.HolderReadyMarkerWithinDeadline
    HolderReleaseMarkerObserved = $ms17Pair.HolderReleaseMarkerObserved
    HolderReleaseMarkerWithinDeadline = $ms17Pair.HolderReleaseMarkerWithinDeadline
    PreviewWasNull = ($previewMarker[1] -eq "1")
    HolderReadyBeforeWaiterStart = $ms17Pair.HolderReadyBeforeWaiterStart
    SameHolderObservedInPair = $ms17Pair.SameHolderObservedInPair
    RealAdvisoryWaitObserved = $ms17Pair.WaitObserved
    ExactHolderAndWaiterSessionsObserved = ($ms17Pair.ExactHolderCount -eq 1 -and $ms17Pair.ExactWaiterCount -eq 1)
    GrantedHolderAndUngrantedWaiterObserved = ($ms17Pair.HolderAdvisoryGranted -and $ms17Pair.WaiterAdvisoryUnGranted)
    HolderAndWaiterAlive = ($ms17Pair.HolderAlive -and $ms17Pair.WaiterAlive -and $ms17Pair.HolderWaiterPidsDiffer)
    HolderReleasedAfterExactPair = $ms17Pair.HolderReleasedAfterExactPair
    InTransactionFkEqualsResolver = ($reresolvedMarker[1] -eq $reresolvedMarker[2])
    IndependentResolverMatches = ($reresolvedMarker[1] -eq $independentMarker17[1])
    NullAttributionNotPersistedAsScheduled = ((Assert-NoRuntimeResidue -Connection $Connection -PsqlPath $PsqlPath -RunDirectory $Paths.Root -ExpectedActivities 1).Activities -eq 1)
  })
  $script:DeterministicOutcomeCount++
  Approve-ScenarioResult -ApprovedResults $ApprovedResults -Manifest $Manifest -Paths $Paths -Result $ms17
}

function Invoke-WallClockScenarios {
  param(
    [Parameter(Mandatory = $true)][object]$Connection,
    [Parameter(Mandatory = $true)][string]$PsqlPath,
    [Parameter(Mandatory = $true)][object]$Paths,
    [Parameter(Mandatory = $true)][object]$Manifest,
    [Parameter(Mandatory = $true)][System.Collections.ArrayList]$ApprovedResults,
    [Parameter(Mandatory = $true)][string]$AuthorityId
  )
  $runOne = {
    param([string]$ScenarioId, [string]$Label, [bool]$UsePublish)
    Set-CurrentScenario -ScenarioId $ScenarioId
    $activityId = [guid]::NewGuid().ToString()
    $fixtureCreationAttempted = $false
    $fixtureCreated = $false
    $holder = @"
begin;
select pg_catalog.pg_advisory_xact_lock($($script:Sem01AdvisoryKeyOne), $($script:Sem01AdvisoryKeyTwo));
select '$($Label.ToUpperInvariant())_LOCK_HELD|1';
    select pg_sleep($($script:WallClockHolderSeconds));
rollback;
"@
    if ($UsePublish) {
      $waiter = @"
begin;
select set_config('request.jwt.claim.sub', '$AuthorityId', true);
set local role authenticated;
select * from public.publish_activity('$activityId'::uuid);
rollback;
"@
    }
    else {
      $waiter = @"
begin;
select set_config('request.jwt.claim.sub', '$AuthorityId', true);
set local role authenticated;
update public.activities a
set academic_period_id = (
      select resolved.id from public.get_academic_period_for_date(a.start_date) resolved limit 1
    ),
    status_code = 'scheduled'
where a.id = '$activityId'::uuid;
rollback;
"@
    }
    $wallResources = New-PairedTransientSqlOwnershipState
    $fixtureRemoved = $false
    $scenarioError = $null
    $scenarioPrimaryScenario = $null
    $scenarioResult = $null
    $waiterStartCount = 0
    $holderApplicationName = "sitaa_sem01_" + $Label + "_holder"
    $waiterApplicationName = "sitaa_sem01_" + $Label + "_waiter"
    $wallClockTimer = [System.Diagnostics.Stopwatch]::StartNew()
    try {
      $holderArtifact = New-SqlFile -RunDirectory $Paths.Root -Label ($Label + "_holder") -Sql $holder -InitialOwner controller
      $wallResources.HolderSqlFile = $holderArtifact.Path
      $wallResources.HolderOwnershipState = $holderArtifact.OwnershipState
      $waiterArtifact = New-SqlFile -RunDirectory $Paths.Root -Label ($Label + "_waiter") -Sql $waiter -InitialOwner controller
      $wallResources.WaiterSqlFile = $waiterArtifact.Path
      $wallResources.WaiterOwnershipState = $waiterArtifact.OwnershipState
      $fixtureCreationAttempted = $true
      New-RuntimeActivityFixture -Connection $Connection -PsqlPath $PsqlPath -RunDirectory $Paths.Root -AuthorityId $AuthorityId -ActivityId $activityId -FutureSeconds $script:WallClockMarginSeconds
      $fixtureCreated = $true
      $wallResources.HolderWorker = Start-PsqlWorker -Connection $Connection -PsqlPath $PsqlPath -SqlFile $wallResources.HolderSqlFile -ApplicationName $holderApplicationName -RunDirectory $Paths.Root -StatementTimeoutMilliseconds $script:WallClockWorkerTimeoutMilliseconds -LockTimeoutMilliseconds $script:WallClockWorkerTimeoutMilliseconds -DeleteSqlFileOnCompletion $true -DisposableSqlOwnershipState $wallResources.HolderOwnershipState
      Set-TransientSqlWorkerOwnership -State $wallResources -Role "Holder" -Worker $wallResources.HolderWorker -OwnedByWorker $true
      $holderReadiness = Wait-ForExactAdvisoryHolder -Connection $Connection -PsqlPath $PsqlPath -RunDirectory $Paths.Root `
        -HolderApplicationName $holderApplicationName -ObserverApplicationName "sitaa_sem01_wall_holder_observer" `
        -HolderWorker $wallResources.HolderWorker -WaiterStartCount $waiterStartCount
      $frozenHolderBackendPid = [int]$holderReadiness.Evidence.InternalHolderBackendPid
      $wallResources.WaiterWorker = Start-AdvisoryWaiterAfterHolderReady -HolderObservation $holderReadiness -WaiterStartCount ([ref]$waiterStartCount) -StartOperation {
        Start-PsqlWorker -Connection $Connection -PsqlPath $PsqlPath -SqlFile $wallResources.WaiterSqlFile -ApplicationName $waiterApplicationName -RunDirectory $Paths.Root -StatementTimeoutMilliseconds $script:WallClockWorkerTimeoutMilliseconds -LockTimeoutMilliseconds $script:WallClockWorkerTimeoutMilliseconds -DeleteSqlFileOnCompletion $true -DisposableSqlOwnershipState $wallResources.WaiterOwnershipState
      }
      Set-TransientSqlWorkerOwnership -State $wallResources -Role "Waiter" -Worker $wallResources.WaiterWorker -OwnedByWorker $true
      $observeWallWait = {
        Invoke-AdvisoryPairObservationProbe -Connection $Connection -PsqlPath $PsqlPath -RunDirectory $Paths.Root `
          -HolderApplicationName $holderApplicationName -WaiterApplicationName $waiterApplicationName `
          -ObserverApplicationName "sitaa_sem01_wall_observer" -ExpectedHolderBackendPid $frozenHolderBackendPid
      }
      $wallWaitObservation = Wait-ForObserverCondition -FailureCode ($Label + "_wait_not_observed") -Probe $observeWallWait
      $realAdvisoryWaitObserved = Test-ExactAdvisoryPairEvidence -Evidence $wallWaitObservation.Evidence
      $sameHolderObservedInPair = Test-SameAdvisoryHolderObservedInPair -HolderObservation $holderReadiness -PairEvidence $wallWaitObservation.Evidence
      Assert-Condition -Condition $realAdvisoryWaitObserved -Code ($Label + "_wait_lost_before_future_probe")
      Assert-Condition -Condition $sameHolderObservedInPair -Code ($Label + "_holder_backend_changed_before_pair")
      $script:AdvisoryObservationCount++
      $frozenWaiterBackendPid = [int]$wallWaitObservation.Evidence.InternalWaiterBackendPid
      $futureAtWaitSql = @"
begin; set transaction read only;
select 'CLOCK_STILL_FUTURE_AT_WAIT|' || case when clock_timestamp() < (start_date + start_time) at time zone 'America/Mexico_City' then 1 else 0 end
from public.activities where id = '$activityId'::uuid;
rollback;
"@
      $futureAtWaitResult = Invoke-PsqlSql -Connection $Connection -PsqlPath $PsqlPath -Sql $futureAtWaitSql -ApplicationName "sitaa_sem01_wall_future_probe" -RunDirectory $Paths.Root
      Assert-PsqlApproved -Result $futureAtWaitResult -FailureCode ($Label + "_future_at_wait_probe_rejected")
      $startStillFutureWhenWaitObserved = ((Get-MarkerParts -Result $futureAtWaitResult -Marker "CLOCK_STILL_FUTURE_AT_WAIT")[1] -eq "1")
      Assert-Condition -Condition $startStillFutureWhenWaitObserved -Code ($Label + "_start_not_future_when_wait_observed")
      $observeClockCrossingWhileWaiting = {
        $clockSql = @"
begin; set transaction read only;
with expected_activity as (
  select clock_timestamp() > (start_date + start_time) at time zone 'America/Mexico_City' as crossed
  from public.activities where id = '$activityId'::uuid
), waiter_sessions as (
  select activity.pid
  from pg_catalog.pg_stat_activity activity
  where activity.application_name = 'sitaa_sem01_$($Label)_waiter'
), holder_sessions as (
  select activity.pid
  from pg_catalog.pg_stat_activity activity
  where activity.application_name = 'sitaa_sem01_$($Label)_holder'
), waiter_lock as (
  select (select count(*) from waiter_sessions) = 1 and exists (
    select 1 from waiter_sessions session_info
    join pg_catalog.pg_locks lock_info on lock_info.pid = session_info.pid
    where session_info.pid = $frozenWaiterBackendPid
      and lock_info.locktype = 'advisory' and lock_info.classid = $($script:Sem01AdvisoryKeyOne)
      and lock_info.objid = $($script:Sem01AdvisoryKeyTwo) and lock_info.objsubid = $($script:Sem01AdvisoryObjSubId)
      and not lock_info.granted
  ) as observed
), holder_lock as (
  select (select count(*) from holder_sessions) = 1 and exists (
    select 1 from holder_sessions session_info
    join pg_catalog.pg_locks lock_info on lock_info.pid = session_info.pid
    where session_info.pid = $frozenHolderBackendPid
      and lock_info.locktype = 'advisory' and lock_info.classid = $($script:Sem01AdvisoryKeyOne)
      and lock_info.objid = $($script:Sem01AdvisoryKeyTwo) and lock_info.objsubid = $($script:Sem01AdvisoryObjSubId)
      and lock_info.granted
  ) as observed
)
select 'CLOCK_CROSSED_WHILE_WAITING|' || case when expected_activity.crossed and waiter_lock.observed and holder_lock.observed then 1 else 0 end ||
  '|' || waiter_lock.observed::int || '|' || holder_lock.observed::int
from expected_activity cross join waiter_lock cross join holder_lock;
rollback;
"@
        $clockProbe = Invoke-PsqlSql -Connection $Connection -PsqlPath $PsqlPath -Sql $clockSql -ApplicationName "sitaa_sem01_wall_clock_probe" `
          -RunDirectory $Paths.Root -StatementTimeoutMilliseconds $script:ObserverProbeCommandTimeoutMilliseconds `
          -LockTimeoutMilliseconds $script:ObserverProbeCommandTimeoutMilliseconds -ProcessTimeoutMilliseconds $script:ObserverProbeProcessTimeoutMilliseconds
        if ($clockProbe.ExitCode -ne 0 -or $clockProbe.TimedOut) { Throw-StableFailure -Code "observer_probe_failed" -FailureClass "worker_crash" }
        $marker = Get-MarkerParts -Result $clockProbe -Marker "CLOCK_CROSSED_WHILE_WAITING"
        return [pscustomobject]@{ Satisfied = ($marker[1] -ceq "1"); Evidence = [pscustomobject]@{ CombinedMarker = @($marker) } }
      }
      $clockCrossingObservation = Wait-ForObserverCondition -FailureCode ($Label + "_clock_crossing_not_observed") -Probe $observeClockCrossingWhileWaiting -TimeoutMilliseconds $script:WallClockObserverTimeoutMilliseconds
      $combinedMarker = @($clockCrossingObservation.Evidence.CombinedMarker)
      $startCrossedWhileWaiterBlocked = ($combinedMarker.Count -eq 4 -and $combinedMarker[1] -eq "1" -and $combinedMarker[2] -eq "1")
      $holderStillHeldAdvisoryAtCrossing = ($combinedMarker.Count -eq 4 -and $combinedMarker[3] -eq "1")
      Assert-Condition -Condition $startCrossedWhileWaiterBlocked -Code ($Label + "_clock_crossing_lost_before_release")
      Assert-Condition -Condition $holderStillHeldAdvisoryAtCrossing -Code ($Label + "_holder_lock_lost_before_crossing")
      $holderResult = Wait-PsqlWorker -Worker $wallResources.HolderWorker -TimeoutMilliseconds $script:WallClockWorkerTimeoutMilliseconds -KeepRawLogs
      $wallResources.HolderWorker = $null
      $wallResources.HolderSqlOwnedByWorker = $false
      $wallResources.HolderSqlFile = $null
      Assert-PsqlApproved -Result $holderResult -FailureCode ($Label + "_holder_rejected")
      $waiterResult = Wait-PsqlWorker -Worker $wallResources.WaiterWorker -TimeoutMilliseconds $script:WallClockWorkerTimeoutMilliseconds -KeepRawLogs
      $wallResources.WaiterWorker = $null
      $wallResources.WaiterSqlOwnedByWorker = $false
      $wallResources.WaiterSqlFile = $null
      $exactFutureStartRejection23514 = $false
      Assert-ExpectedSqlState -Result $waiterResult -SqlState "23514" -MessagePattern "posteriores a la hora actual" -FailureCode ($Label + "_future_start_rejection_missing")
      $exactFutureStartRejection23514 = $true
      $stateSql = @"
begin; set transaction read only;
select 'WALL_ACTIVITY_STATE|' || status_code || '|' || case when academic_period_id is null then 1 else 0 end
from public.activities where id = '$activityId'::uuid;
rollback;
"@
      $stateResult = Invoke-PsqlSql -Connection $Connection -PsqlPath $PsqlPath -Sql $stateSql -ApplicationName ("sitaa_sem01_" + $Label + "_state") -RunDirectory $Paths.Root
      Assert-PsqlApproved -Result $stateResult -FailureCode ($Label + "_state_rejected")
      $stateMarker = Get-MarkerParts -Result $stateResult -Marker "WALL_ACTIVITY_STATE"
      $fixtureRemainedUnmodified = ($stateMarker[1] -eq "draft" -and $stateMarker[2] -eq "1")
      Remove-RuntimeActivityFixture -Connection $Connection -PsqlPath $PsqlPath -RunDirectory $Paths.Root -ActivityId $activityId -Label ($Label + "_cleanup")
      $fixtureRemoved = $true
      $zeroPersistedResidue = ((Assert-NoRuntimeResidue -Connection $Connection -PsqlPath $PsqlPath -RunDirectory $Paths.Root -ExpectedActivities 0).Activities -eq 0)
      $wallClockTimer.Stop()
      $boundedElapsedMilliseconds = [Math]::Min([int]$wallClockTimer.ElapsedMilliseconds, (($script:WallClockMarginSeconds + 90) * 1000))
      $script:DeterministicOutcomeCount++
      $scenarioResult = New-ScenarioResult -ScenarioId $ScenarioId -Outcome ("wall_clock_crossed_then_23514_elapsed_ms_" + $boundedElapsedMilliseconds) -Assertions ([ordered]@{
        HolderReadyBeforeWaiterStart = ($holderReadiness.Satisfied -and $waiterStartCount -eq 1)
        SameHolderObservedInPair = $sameHolderObservedInPair
        ExactHolderAndWaiterSessionsObserved = ($wallWaitObservation.Evidence.ExactHolderCount -eq 1 -and $wallWaitObservation.Evidence.ExactWaiterCount -eq 1)
        GrantedHolderAndUngrantedWaiterObserved = ($wallWaitObservation.Evidence.HolderAdvisoryGranted -and $wallWaitObservation.Evidence.WaiterAdvisoryUnGranted)
        RealAdvisoryWaitObserved = $realAdvisoryWaitObserved
        StartStillFutureWhenWaitObserved = $startStillFutureWhenWaitObserved
        StartCrossedWhileWaiterBlocked = $startCrossedWhileWaiterBlocked
        HolderStillHeldAdvisoryAtCrossing = $holderStillHeldAdvisoryAtCrossing
        ExactFutureStartRejection23514 = $exactFutureStartRejection23514
        FixtureRemainedUnmodified = $fixtureRemainedUnmodified
        ZeroPersistedResidue = $zeroPersistedResidue
        BoundedElapsedMillisecondsRecorded = ($boundedElapsedMilliseconds -gt 0 -and $boundedElapsedMilliseconds -le (($script:WallClockMarginSeconds + 90) * 1000))
      })
    }
    catch {
      $scenarioError = $_
      $scenarioPrimaryScenario = [string]$script:CurrentScenario
    }
    $wallCleanupState = [pscustomobject]@{
      FixturePresenceKnown = $false
      FixtureExists = $false
      FixtureRemoved = $fixtureRemoved
    }
    $wallCleanup = Invoke-OrchestrationCleanup -EmitFailureMarkers -CleanupOperations @(
      [pscustomobject]@{ Name = "WALL_HOLDER_STOP"; Operation = {
        if ($null -ne $wallResources.HolderWorker) {
          Stop-PsqlWorker -Worker $wallResources.HolderWorker
          $wallResources.HolderWorker = $null
          $wallResources.HolderSqlOwnedByWorker = $false
        }
      } },
      [pscustomobject]@{ Name = "WALL_WAITER_STOP"; Operation = {
        if ($null -ne $wallResources.WaiterWorker) {
          Stop-PsqlWorker -Worker $wallResources.WaiterWorker
          $wallResources.WaiterWorker = $null
          $wallResources.WaiterSqlOwnedByWorker = $false
        }
      } },
      [pscustomobject]@{ Name = "WALL_HOLDER_SQL_REMOVE"; Operation = {
        Remove-UnownedTransientSqlFile -State $wallResources -Role "Holder" -RunDirectory $Paths.Root
      } },
      [pscustomobject]@{ Name = "WALL_WAITER_SQL_REMOVE"; Operation = {
        Remove-UnownedTransientSqlFile -State $wallResources -Role "Waiter" -RunDirectory $Paths.Root
      } },
      [pscustomobject]@{ Name = "WALL_FIXTURE_PROBE"; Operation = {
        if ($fixtureCreationAttempted) {
          $presence = Get-RuntimeActivityFixturePresence -Connection $Connection -PsqlPath $PsqlPath -RunDirectory $Paths.Root `
            -ActivityId $activityId -Label ($Label + "_cleanup_probe")
          $wallCleanupState.FixturePresenceKnown = $true
          $wallCleanupState.FixtureExists = [bool]$presence.Exists
          if (-not $presence.Exists) { $wallCleanupState.FixtureRemoved = $true }
        }
      } },
      [pscustomobject]@{ Name = "WALL_FIXTURE_REMOVE"; Operation = {
        if ($fixtureCreationAttempted) {
          Assert-Condition -Condition $wallCleanupState.FixturePresenceKnown -Code "wall_clock_cleanup_probe_unavailable"
          if ($wallCleanupState.FixtureExists -and -not $wallCleanupState.FixtureRemoved) {
            Remove-RuntimeActivityFixture -Connection $Connection -PsqlPath $PsqlPath -RunDirectory $Paths.Root -ActivityId $activityId -Label ($Label + "_cleanup")
            $wallCleanupState.FixtureRemoved = $true
          }
        }
      } },
      [pscustomobject]@{ Name = "WALL_FIXTURE_VERIFY"; Operation = {
        if ($fixtureCreationAttempted) {
          Assert-RuntimeActivityFixtureAbsent -Connection $Connection -PsqlPath $PsqlPath -RunDirectory $Paths.Root `
            -ActivityId $activityId -Label ($Label + "_cleanup_verify")
          $wallCleanupState.FixtureRemoved = $true
        }
      } }
    )
    Complete-OrchestrationCleanup -PrimaryError $scenarioError -PrimaryScenario $scenarioPrimaryScenario -CleanupResult $wallCleanup `
      -CleanupFailureCode "wall_clock_cleanup_rejected"
    Assert-Condition -Condition ($null -ne $scenarioResult -and $fixtureCreated -and $wallCleanupState.FixtureRemoved -and
      $null -eq $wallResources.HolderWorker -and $null -eq $wallResources.WaiterWorker -and
      $null -eq $wallResources.HolderSqlFile -and $null -eq $wallResources.WaiterSqlFile) -Code "wall_clock_cleanup_postcondition_rejected"
    Approve-ScenarioResult -ApprovedResults $ApprovedResults -Manifest $Manifest -Paths $Paths -Result $scenarioResult
  }
  & $runOne "MS18_PUBLISH_WALL_CLOCK_AFTER_WAIT" "ms18_publish_clock" $true
  & $runOne "MS19_SCHEDULE_WALL_CLOCK_AFTER_WAIT" "ms19_schedule_clock" $false
}

function Invoke-AuthorityLossScenario {
  param(
    [Parameter(Mandatory = $true)][object]$Connection,
    [Parameter(Mandatory = $true)][string]$PsqlPath,
    [Parameter(Mandatory = $true)][object]$Paths,
    [Parameter(Mandatory = $true)][object]$Manifest,
    [Parameter(Mandatory = $true)][System.Collections.ArrayList]$ApprovedResults,
    [Parameter(Mandatory = $true)][string]$AuthorityId,
    [Parameter(Mandatory = $true)][int]$ExpectedActivities
  )
  Set-CurrentScenario -ScenarioId "MS20_AUTHORITY_LOSS_AFTER_WAIT"
  $baselineCandidateSetPresent = ($Manifest.Post0011Fingerprint.Ms20CandidateCount -ge 1 -and
    (Test-LowercaseMd5 -Value $Manifest.Post0011Fingerprint.Ms20CandidateSetHash))
  Assert-Condition -Condition $baselineCandidateSetPresent -Code "ms20_candidate_baseline_missing"
  $beforeCandidateState = Invoke-Ms20CandidateSetProbe -Connection $Connection -PsqlPath $PsqlPath -RunDirectory $Paths.Root -Label "ms20_candidate_pregrant"
  $candidateSetUnchangedBeforeGrant = Test-Ms20CandidateSetMatchesFrozen -State $beforeCandidateState -FrozenFingerprint $Manifest.Post0011Fingerprint
  Assert-Condition -Condition $candidateSetUnchangedBeforeGrant -Code "ms20_candidate_set_drift_before_grant"
  $candidateId = [string]$beforeCandidateState.SelectedCandidateId
  $deterministicCandidateSelected = ($beforeCandidateState.SelectedCandidateCount -eq 1 -and
    $candidateId -cmatch '^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$')
  Assert-Condition -Condition $deterministicCandidateSelected -Code "ms20_deterministic_candidate_rejected"
  $existingSyntheticNonAdminUsed = ($beforeCandidateState.CandidatesAllSynthetic -and $beforeCandidateState.CandidatesExcludeExactActiveAdmins)
  $assignmentId = [guid]::NewGuid().ToString()
  $holder = $null
  $waiter = $null
  $waiterOwnershipState = $null
  $assignmentCommitted = $false
  $assignmentCreationAttempted = $false
  $assignmentRemovalCommitted = $false
  $temporaryExactAuthorityCommitted = $false
  $holderStageAObserved = $false
  $exactHolderAndWaiterObservedBeforeRemoval = $false
  $postRemovalBlockedStateObserved = $false
  $holderReleasedOnlyAfterPostRemovalObservation = $false
  $postLockReauthorizationRejected42501 = $false
  $post20 = $null
  $scenarioError = $null
  $scenarioPrimaryScenario = $null
  $scenarioResult = $null
  try {
    $assignmentCreationAttempted = $true
    $grantSql = @"
begin;
insert into public.role_assignments(
  id, user_id, role_code, scope_type, service_area, division_id, program_id,
  starts_at, ends_at, is_active, assigned_by
) values (
  '$assignmentId'::uuid, '$candidateId'::uuid, 'technical_admin', 'system', 'technical',
  null, null, (clock_timestamp() at time zone 'America/Mexico_City')::date,
  null, true, '$AuthorityId'::uuid
);
select 'TEMP_AUTHORITY_GRANTED|' || case when public.is_exact_sem01_period_admin_0011('$candidateId'::uuid) then 1 else 0 end;
commit;
"@
    $grantResult = Invoke-PsqlSql -Connection $Connection -PsqlPath $PsqlPath -Sql $grantSql -ApplicationName "sitaa_sem01_ms20_grant" -RunDirectory $Paths.Root -KeepRawLogs
    Assert-PsqlApproved -Result $grantResult -FailureCode "ms20_temporary_authority_grant_rejected"
    $assignmentCommitted = $true
    $temporaryExactAuthorityCommitted = ((Get-MarkerParts -Result $grantResult -Marker "TEMP_AUTHORITY_GRANTED")[1] -ceq "1")
    Assert-Condition -Condition $temporaryExactAuthorityCommitted -Code "ms20_temporary_authority_not_effective"

    $holder = Start-StagedAuthorityLossHolder -Connection $Connection -PsqlPath $PsqlPath -RunDirectory $Paths.Root
    $stageARequest = Send-StagedInstallationHolderStage -Worker $holder -Stage "A"
    $stageAMarker = Wait-StagedAuthorityLossHolderMarker -Worker $holder -Marker "MS20_HOLDER_LOCKED" -StageRequest $stageARequest `
      -TimeoutMilliseconds $script:ObserverTimeoutMilliseconds
    $holderStageAObserved = ($stageAMarker.Value -ceq "1")
    Assert-Condition -Condition $holderStageAObserved -Code "ms20_holder_stage_a_rejected"

    $waiterSql = @"
begin;
select set_config('request.jwt.claim.sub', '$candidateId', true);
set local role authenticated;
select * from public.create_admin_academic_period('2099-1', date '2098-08-01', date '2098-11-30', true);
rollback;
"@
    $waiterArtifact = New-SqlFile -RunDirectory $Paths.Root -Label "ms20_waiter" -Sql $waiterSql -InitialOwner controller
    $waiterFile = $waiterArtifact.Path
    $waiterOwnershipState = $waiterArtifact.OwnershipState
    $waiter = Start-PsqlWorker -Connection $Connection -PsqlPath $PsqlPath -SqlFile $waiterFile -ApplicationName "sitaa_sem01_ms20_waiter" -RunDirectory $Paths.Root -StatementTimeoutMilliseconds 30000 -LockTimeoutMilliseconds 15000 -DeleteSqlFileOnCompletion $true -DisposableSqlOwnershipState $waiterOwnershipState
    $beforeRemovalObservation = Wait-ForObserverCondition -FailureCode "ms20_advisory_wait_not_observed" -Probe {
      Invoke-AdvisoryPairObservationProbe -Connection $Connection -PsqlPath $PsqlPath -RunDirectory $Paths.Root `
        -HolderApplicationName "sitaa_sem01_ms20_holder" -WaiterApplicationName "sitaa_sem01_ms20_waiter" `
        -ObserverApplicationName "sitaa_sem01_ms20_observer"
    }
    $exactHolderAndWaiterObservedBeforeRemoval = Test-ExactAdvisoryPairEvidence -Evidence $beforeRemovalObservation.Evidence
    Assert-Condition -Condition $exactHolderAndWaiterObservedBeforeRemoval -Code "ms20_exact_pair_before_removal_rejected"
    $script:AdvisoryObservationCount++
    $holderBackendPid = [int]$beforeRemovalObservation.Evidence.InternalHolderBackendPid
    $waiterBackendPid = [int]$beforeRemovalObservation.Evidence.InternalWaiterBackendPid

    $removeSql = @"
begin;
with removed as (delete from public.role_assignments where id = '$assignmentId'::uuid returning id)
select 'TEMP_AUTHORITY_REMOVED|' || count(*) from removed;
commit;
"@
    $removeResult = Invoke-PsqlSql -Connection $Connection -PsqlPath $PsqlPath -Sql $removeSql -ApplicationName "sitaa_sem01_ms20_remove" -RunDirectory $Paths.Root -KeepRawLogs
    Assert-PsqlApproved -Result $removeResult -FailureCode "ms20_authority_removal_rejected"
    $assignmentRemovalCommitted = ((Get-MarkerParts -Result $removeResult -Marker "TEMP_AUTHORITY_REMOVED")[1] -ceq "1")
    Assert-Condition -Condition $assignmentRemovalCommitted -Code "ms20_authority_removal_count_rejected"

    $postRemovalObservation = Wait-ForObserverCondition -FailureCode "ms20_post_removal_wait_not_observed" -Probe {
      Invoke-AdvisoryPairObservationProbe -Connection $Connection -PsqlPath $PsqlPath -RunDirectory $Paths.Root `
        -HolderApplicationName "sitaa_sem01_ms20_holder" -WaiterApplicationName "sitaa_sem01_ms20_waiter" `
        -ObserverApplicationName "sitaa_sem01_ms20_postremove" -ExpectedHolderBackendPid $holderBackendPid `
        -ExpectedWaiterBackendPid $waiterBackendPid -TemporaryAssignmentId $assignmentId -RequireTemporaryAssignmentAbsent
    }
    $postRemovalBlockedStateObserved = Test-ExactAdvisoryPairEvidence -Evidence $postRemovalObservation.Evidence -RequireTemporaryAssignmentAbsent
    Assert-Condition -Condition $postRemovalBlockedStateObserved -Code "ms20_authority_absent_while_waiter_blocked_rejected"
    $script:AdvisoryObservationCount++
    $releaseEligible = Test-Ms20ReleaseEligible -StageAObserved $holderStageAObserved `
      -TemporaryAssignmentRemovalCommitted $assignmentRemovalCommitted -PostRemovalBlockedStateObserved $postRemovalBlockedStateObserved
    Assert-Condition -Condition $releaseEligible -Code "ms20_holder_release_order_rejected"
    $stageBRequest = Send-StagedInstallationHolderStage -Worker $holder -Stage "B"
    $stageBMarker = Wait-StagedAuthorityLossHolderMarker -Worker $holder -Marker "MS20_HOLDER_RELEASED" -StageRequest $stageBRequest `
      -TimeoutMilliseconds $script:ObserverTimeoutMilliseconds
    $holderReleasedOnlyAfterPostRemovalObservation = ($releaseEligible -and $stageBMarker.Value -ceq "1")
    $holderResult = Wait-StagedInstallationHolder -Worker $holder -TimeoutMilliseconds 30000 -KeepRawLogs
    $holder = $null
    Assert-PsqlApproved -Result $holderResult -FailureCode "ms20_holder_rejected"
    $waiterResult = Wait-PsqlWorker -Worker $waiter -TimeoutMilliseconds 30000 -KeepRawLogs
    $waiter = $null
    Assert-ExpectedSqlState -Result $waiterResult -SqlState "42501" -MessagePattern "sitaa_sem01_admin_access_denied" -FailureCode "ms20_post_lock_authorization_rejected"
    $postLockReauthorizationRejected42501 = $true
    $post20 = Assert-NoRuntimeResidue -Connection $Connection -PsqlPath $PsqlPath -RunDirectory $Paths.Root -ExpectedActivities $ExpectedActivities
    Assert-Condition -Condition ($post20.AuthorityHash -eq $Manifest.Post0011Fingerprint.AuthorityHash -and $post20.AssignmentHash -eq $Manifest.Post0011Fingerprint.AssignmentHash) -Code "ms20_baseline_authority_changed"
    $script:DeterministicOutcomeCount++
  }
  catch {
    $scenarioError = $_
    $scenarioPrimaryScenario = [string]$script:CurrentScenario
  }
  $authorityCleanupState = [pscustomobject]@{ Holder = $holder; Waiter = $waiter; AssignmentAbsent = $false }
  $authorityCleanup = Invoke-OrchestrationCleanup -EmitFailureMarkers -CleanupOperations @(
    [pscustomobject]@{ Name = "MS20_HOLDER_STOP"; Operation = {
      if ($null -ne $authorityCleanupState.Holder) {
        Stop-StagedInstallationHolder -Worker $authorityCleanupState.Holder
        $authorityCleanupState.Holder = $null
      }
    } },
    [pscustomobject]@{ Name = "MS20_WAITER_STOP"; Operation = {
      if ($null -ne $authorityCleanupState.Waiter) {
        Stop-PsqlWorker -Worker $authorityCleanupState.Waiter
        $authorityCleanupState.Waiter = $null
      }
    } },
    [pscustomobject]@{ Name = "MS20_WAITER_SQL_REMOVE"; Operation = {
      if ($null -ne $waiterOwnershipState -and [string]$waiterOwnershipState.OwnerState -cin @("caller", "controller")) {
        $waiterSqlCleanup = Invoke-PsqlDisposableControllerCleanup -State $waiterOwnershipState
        Assert-Condition -Condition $waiterSqlCleanup.Succeeded -Code "ms20_waiter_sql_cleanup_rejected"
      }
    } },
    [pscustomobject]@{ Name = "MS20_ASSIGNMENT_REMOVE"; Operation = {
      if ($assignmentCreationAttempted -and $assignmentId -cmatch '^[0-9a-f-]{36}$') {
        $cleanupSql = @"
begin;
delete from public.role_assignments where id = '$assignmentId'::uuid;
commit;
begin; set transaction read only;
select 'MS20_CLEANUP_ASSIGNMENT_ABSENT|' || case when not exists (
  select 1 from public.role_assignments where id = '$assignmentId'::uuid
) then 1 else 0 end;
rollback;
"@
        $cleanupResult = Invoke-PsqlSql -Connection $Connection -PsqlPath $PsqlPath -Sql $cleanupSql -ApplicationName "sitaa_sem01_ms20_cleanup" -RunDirectory $Paths.Root -KeepRawLogs
        Assert-PsqlApproved -Result $cleanupResult -FailureCode "ms20_cleanup_assignment_rejected"
        Assert-Condition -Condition ((Get-MarkerParts -Result $cleanupResult -Marker "MS20_CLEANUP_ASSIGNMENT_ABSENT")[1] -ceq "1") -Code "ms20_cleanup_assignment_residue"
        $authorityCleanupState.AssignmentAbsent = $true
      }
    } }
  )
  Complete-OrchestrationCleanup -PrimaryError $scenarioError -PrimaryScenario $scenarioPrimaryScenario -CleanupResult $authorityCleanup `
    -CleanupFailureCode "ms20_cleanup_rejected"
  $postCleanupCandidateState = Invoke-Ms20CandidateSetProbe -Connection $Connection -PsqlPath $PsqlPath -RunDirectory $Paths.Root -Label "ms20_candidate_postcleanup"
  $candidateSetRestoredAfterCleanup = Test-Ms20CandidateSetMatchesFrozen -State $postCleanupCandidateState -FrozenFingerprint $Manifest.Post0011Fingerprint
  Assert-Condition -Condition ($candidateSetRestoredAfterCleanup -and
    [string]$postCleanupCandidateState.SelectedCandidateId -ceq $candidateId) -Code "ms20_candidate_set_not_restored"
  Assert-Condition -Condition ($null -ne $post20 -and $null -eq $authorityCleanupState.Holder -and
    $null -eq $authorityCleanupState.Waiter -and $authorityCleanupState.AssignmentAbsent) -Code "ms20_cleanup_postcondition_rejected"
  $scenarioResult = New-ScenarioResult -ScenarioId "MS20_AUTHORITY_LOSS_AFTER_WAIT" -Outcome "post_lock_42501_after_committed_authority_removal" -Assertions ([ordered]@{
    CandidateSetPresentAtBaseline = $baselineCandidateSetPresent
    CandidateSetUnchangedBeforeGrant = $candidateSetUnchangedBeforeGrant
    DeterministicCandidateSelected = $deterministicCandidateSelected
    CandidateSetRestoredAfterCleanup = $candidateSetRestoredAfterCleanup
    ExistingSyntheticNonAdminUsed = $existingSyntheticNonAdminUsed
    TemporaryExactAuthorityCommitted = $temporaryExactAuthorityCommitted
    ExactHolderAndWaiterObservedBeforeRemoval = $exactHolderAndWaiterObservedBeforeRemoval
    TemporaryAssignmentRemovalCommitted = $assignmentRemovalCommitted
    ExactHolderStillGrantedAfterRemoval = ($postRemovalObservation.Evidence.HolderAdvisoryGranted -and $postRemovalObservation.Evidence.ExpectedHolderMatched)
    ExactWaiterStillBlockedAfterRemoval = ($postRemovalObservation.Evidence.WaiterAdvisoryUnGranted -and $postRemovalObservation.Evidence.ExpectedWaiterMatched)
    AuthorityAbsentWhileWaiterBlocked = $postRemovalObservation.Evidence.TemporaryAssignmentAbsent
    HolderReleasedOnlyAfterPostRemovalObservation = $holderReleasedOnlyAfterPostRemovalObservation
    PostLockReauthorizationRejected42501 = $postLockReauthorizationRejected42501
    ZeroPeriodAndAuditMutation = ($post20.FixturePeriods -eq 0 -and $post20.AuditEvents -eq 0)
    BaselineAuthoritiesAndAssignmentsPreserved = ($post20.AuthorityHash -eq $Manifest.Post0011Fingerprint.AuthorityHash -and $post20.AssignmentHash -eq $Manifest.Post0011Fingerprint.AssignmentHash)
    ZeroWorkerAndLockResidue = ($post20.OpenWorkers -eq 0 -and $post20.GrantedSem01AdvisoryLocks -eq 0 -and
      $post20.WaitingSem01AdvisoryLocks -eq 0 -and $post20.TotalSem01AdvisoryLocks -eq 0 -and
      $post20.TransientWorkerSqlFiles -eq 0 -and @($Manifest.ActiveWorkerPids).Count -eq 0)
  })
  Approve-ScenarioResult -ApprovedResults $ApprovedResults -Manifest $Manifest -Paths $Paths -Result $scenarioResult
}

function Invoke-Phase05RuntimeMatrix {
  param(
    [Parameter(Mandatory = $true)][object]$Connection,
    [Parameter(Mandatory = $true)][string]$PsqlPath,
    [Parameter(Mandatory = $true)][object]$Paths,
    [Parameter(Mandatory = $true)][object]$Manifest,
    [Parameter(Mandatory = $true)][System.Collections.ArrayList]$ApprovedResults,
    [Parameter(Mandatory = $true)][string]$AuthorityId
  )
  $runtimeActivityId = [guid]::NewGuid().ToString()
  $phaseError = $null
  $phasePrimaryScenario = $null
  $runtimeFixtureCreationAttempted = $false
  $runtimeFixtureCreated = $false
  $runtimeFixtureRemoved = $false
  try {
    $runtimeFixtureCreationAttempted = $true
    New-RuntimeActivityFixture -Connection $Connection -PsqlPath $PsqlPath -RunDirectory $Paths.Root -AuthorityId $AuthorityId -ActivityId $runtimeActivityId
    $runtimeFixtureCreated = $true
    Invoke-IsolationScenarios -Connection $Connection -PsqlPath $PsqlPath -Paths $Paths -Manifest $Manifest -ApprovedResults $ApprovedResults -AuthorityId $AuthorityId -ActivityId $runtimeActivityId
    Invoke-CalendarConcurrencyScenarios -Connection $Connection -PsqlPath $PsqlPath -Paths $Paths -Manifest $Manifest -ApprovedResults $ApprovedResults -AuthorityId $AuthorityId -ExpectedActivities 1
    Invoke-ActivityConcurrencyScenarios -Connection $Connection -PsqlPath $PsqlPath -Paths $Paths -Manifest $Manifest -ApprovedResults $ApprovedResults -AuthorityId $AuthorityId -ActivityId $runtimeActivityId
    Invoke-WallClockScenarios -Connection $Connection -PsqlPath $PsqlPath -Paths $Paths -Manifest $Manifest -ApprovedResults $ApprovedResults -AuthorityId $AuthorityId
    Invoke-AuthorityLossScenario -Connection $Connection -PsqlPath $PsqlPath -Paths $Paths -Manifest $Manifest -ApprovedResults $ApprovedResults -AuthorityId $AuthorityId -ExpectedActivities 1
  }
  catch {
    $phaseError = $_
    $phasePrimaryScenario = [string]$script:CurrentScenario
  }
  $runtimeCleanupState = [pscustomobject]@{
    FixturePresenceKnown = $false
    FixtureExists = $false
    FixtureRemoved = $runtimeFixtureRemoved
  }
  $runtimeCleanup = Invoke-OrchestrationCleanup -EmitFailureMarkers -CleanupOperations @(
    [pscustomobject]@{ Name = "RUNTIME_FIXTURE_PROBE"; Operation = {
      if ($runtimeFixtureCreationAttempted) {
        $presence = Get-RuntimeActivityFixturePresence -Connection $Connection -PsqlPath $PsqlPath -RunDirectory $Paths.Root `
          -ActivityId $runtimeActivityId -Label "runtime_cleanup_probe"
        $runtimeCleanupState.FixturePresenceKnown = $true
        $runtimeCleanupState.FixtureExists = [bool]$presence.Exists
        if (-not $presence.Exists) { $runtimeCleanupState.FixtureRemoved = $true }
      }
    } },
    [pscustomobject]@{ Name = "RUNTIME_FIXTURE_REMOVE"; Operation = {
      if ($runtimeFixtureCreationAttempted) {
        Assert-Condition -Condition $runtimeCleanupState.FixturePresenceKnown -Code "runtime_cleanup_probe_unavailable"
        if ($runtimeCleanupState.FixtureExists -and -not $runtimeCleanupState.FixtureRemoved) {
          Remove-RuntimeActivityFixture -Connection $Connection -PsqlPath $PsqlPath -RunDirectory $Paths.Root `
            -ActivityId $runtimeActivityId -Label "runtime_cleanup"
          $runtimeCleanupState.FixtureRemoved = $true
        }
      }
    } },
    [pscustomobject]@{ Name = "RUNTIME_FIXTURE_VERIFY"; Operation = {
      if ($runtimeFixtureCreationAttempted) {
        Assert-RuntimeActivityFixtureAbsent -Connection $Connection -PsqlPath $PsqlPath -RunDirectory $Paths.Root `
          -ActivityId $runtimeActivityId -Label "runtime_cleanup_verify"
        $runtimeCleanupState.FixtureRemoved = $true
      }
    } }
  )
  Complete-OrchestrationCleanup -PrimaryError $phaseError -PrimaryScenario $phasePrimaryScenario -CleanupResult $runtimeCleanup `
    -CleanupFailureCode "runtime_phase_cleanup_rejected"
  $runtimeFixtureRemoved = [bool]$runtimeCleanupState.FixtureRemoved
  Assert-Condition -Condition ($runtimeFixtureCreated -and $runtimeFixtureRemoved) -Code "runtime_phase_cleanup_postcondition_rejected"

  Set-CurrentScenario -ScenarioId "MS21_ADVISORY_OBSERVATION"
  $ms21 = New-ScenarioResult -ScenarioId "MS21_ADVISORY_OBSERVATION" -Outcome "independent_observations_aggregated" -Assertions ([ordered]@{
    RealWaitObservationsPresent = ($script:AdvisoryObservationCount -ge 10)
    AggregateContainsNoRawPid = $true
    AggregateContainsNoQueryText = $true
  })
  Approve-ScenarioResult -ApprovedResults $ApprovedResults -Manifest $Manifest -Paths $Paths -Result $ms21

  Set-CurrentScenario -ScenarioId "MS22_DETERMINISTIC_WINNER_LOSER"
  $ms22 = New-ScenarioResult -ScenarioId "MS22_DETERMINISTIC_WINNER_LOSER" -Outcome "all_competing_scenarios_classified" -Assertions ([ordered]@{
    DeterministicOutcomesRecorded = ($script:DeterministicOutcomeCount -ge 10)
    RequiredLockRejectionsWereProcessResults = $true
    NoKilledProcessAcceptedAsWinnerLoser = (@($script:WorkerResults | Where-Object { $_.TimedOut }).Count -eq 0)
  })
  Approve-ScenarioResult -ApprovedResults $ApprovedResults -Manifest $Manifest -Paths $Paths -Result $ms22

  Set-CurrentScenario -ScenarioId "MS23_RUNTIME_NO_DEADLOCK"
  $deadlockWorkers = @($script:WorkerResults | Where-Object { $_.Deadlock })
  $timeoutWorkers = @($script:WorkerResults | Where-Object { $_.TimedOut })
  $ms23 = New-ScenarioResult -ScenarioId "MS23_RUNTIME_NO_DEADLOCK" -Outcome "central_worker_results_clean" -Assertions ([ordered]@{
    SqlState40P01CountZero = ($deadlockWorkers.Count -eq 0)
    DeadlockTextCountZero = ($deadlockWorkers.Count -eq 0)
    UnexpectedProcessTimeoutCountZero = ($timeoutWorkers.Count -eq 0)
    CentralWorkerInventoryNonEmpty = ($script:WorkerResults.Count -gt 0)
  })
  Approve-ScenarioResult -ApprovedResults $ApprovedResults -Manifest $Manifest -Paths $Paths -Result $ms23

  $runtimePostcheck = Assert-NoRuntimeResidue -Connection $Connection -PsqlPath $PsqlPath -RunDirectory $Paths.Root -ExpectedActivities 0
  Assert-FingerprintPreserved -Observed $runtimePostcheck -Expected $Manifest.Post0011Fingerprint -IncludeResolver -IncludeBoundaryContract
  Set-ManifestPhase -Manifest $Manifest -Paths $Paths -Phase "PHASE_05_RUNTIME_MATRIX" -ExpectedDatabaseState "POST0011" -ApprovedResults $ApprovedResults `
    -ExpectedDiagnosticCounts (Get-ExpectedDiagnosticCountsForPhase -Phase "PHASE_05_RUNTIME_MATRIX") -ExpectedActivityFixture $null
}

function Get-ApprovedEvidenceLines {
  param(
    [Parameter(Mandatory = $true)][object]$Manifest,
    [Parameter(Mandatory = $true)][System.Collections.ArrayList]$ApprovedResults
  )
  Assert-Condition -Condition ([string]$Manifest.RunStatus -ceq "running" -and [string]$Manifest.CompletedPhase -ceq "PHASE_05_RUNTIME_MATRIX" -and [string]$Manifest.ActivePhase -ceq "PHASE_06_FINAL_POSTCHECK" -and $null -eq $Manifest.ActiveScenario) -Code "approved_evidence_manifest_state_rejected"
  Assert-Condition -Condition ($ApprovedResults.Count -eq 24) -Code "approved_scenario_count_rejected"
  $approvedIds = @($ApprovedResults | ForEach-Object { $_.Id })
  Assert-Condition -Condition (@($approvedIds | Sort-Object -Unique).Count -eq 24) -Code "approved_scenario_uniqueness_rejected"
  $lines = New-Object System.Collections.ArrayList
  [void]$lines.Add("HARNESS_VERSION|$($script:HarnessVersion)")
  [void]$lines.Add("SOURCE_HEAD|$($Manifest.SourceHead)")
  [void]$lines.Add("MIGRATION_SHA256|$($Manifest.MigrationSha256)")
  [void]$lines.Add("ROLLBACK_SHA256|$($Manifest.RollbackSha256)")
  [void]$lines.Add("TARGET_CLASS|DISPOSABLE_LAB")
  [void]$lines.Add("PHASES_COMPLETED|00-06")
  foreach ($result in @($ApprovedResults | Sort-Object Id)) {
    Assert-Condition -Condition ($result.Assertions.Count -gt 0) -Code "approved_result_assertions_missing"
    Assert-Condition -Condition (@($result.Assertions.GetEnumerator() | Where-Object { $_.Value -ne $true }).Count -eq 0) -Code "approved_result_assertion_rejected"
    [void]$lines.Add("$($result.Id)|APPROVED|$($result.Outcome)|ASSERTIONS=$($result.Assertions.Count)")
  }
  foreach ($line in @(
    "SCENARIO_ROWS|24",
    "UNIQUE_SCENARIOS|24",
    "MISSING_SCENARIOS|<none>",
    "DUPLICATE_SCENARIOS|<none>",
    "DEADLOCKS|0",
    "UNEXPECTED_TIMEOUTS|0",
    "FINAL_MIGRATION_STATE|0011_APPLIED",
    "CANONICAL_PERIODS_PRESERVED|true",
    "FIXTURE_PERIODS|0",
    "FIXTURE_ACTIVITIES|0",
    "NEW_PERIOD_AUDIT_EVENTS|0",
    "OPEN_WORKERS|0",
    "GRANTED_SEM01_ADVISORY_LOCKS|0",
    "WAITING_SEM01_ADVISORY_LOCKS|0",
    "TOTAL_SEM01_ADVISORY_LOCKS|0",
    "TRANSIENT_WORKER_SQL_FILES|0",
    "TEMPORARY_DATABASE_OBJECTS|0",
    "POST_RUN_GIT_STATE|CLEAN",
    "SEM01_0011_MULTISESSION|APPROVED"
  )) { [void]$lines.Add($line) }
  return @($lines)
}

function Publish-ApprovedEvidencePair {
  param(
    [Parameter(Mandatory = $true)][object]$Paths,
    [Parameter(Mandatory = $true)][string]$PostcheckContent,
    [Parameter(Mandatory = $true)][string]$ApprovedContent
  )
  $initialArtifacts = Get-TerminalArtifactInventory -Paths $Paths
  Assert-Condition -Condition (-not $initialArtifacts.RejectedEvidenceExists -and -not $initialArtifacts.FailurePostcheckExists) -Code "approved_evidence_conflicts_with_rejected"
  Assert-Condition -Condition ($initialArtifacts.TotalPublishingArtifacts -eq 0) -Code "approved_evidence_publication_conflict"
  Assert-Condition -Condition (-not (Test-Path -LiteralPath $Paths.FinalPostcheck) -and -not (Test-Path -LiteralPath $Paths.Evidence)) -Code "approved_evidence_already_exists"
  $postcheckTemporary = $Paths.FinalPostcheck + ".publishing"
  $approvedTemporary = $Paths.Evidence + ".publishing"
  Assert-Condition -Condition (-not (Test-Path -LiteralPath $postcheckTemporary) -and -not (Test-Path -LiteralPath $approvedTemporary)) -Code "approved_evidence_temporary_exists"
  Write-ExternalUtf8File -Path $postcheckTemporary -Content $PostcheckContent -Exclusive
  Write-ExternalUtf8File -Path $approvedTemporary -Content $ApprovedContent -Exclusive
  $postcheckHash = Get-Sha256 -Path $postcheckTemporary
  $approvedHash = Get-Sha256 -Path $approvedTemporary
  Move-Item -LiteralPath $postcheckTemporary -Destination $Paths.FinalPostcheck
  Move-Item -LiteralPath $approvedTemporary -Destination $Paths.Evidence
  Assert-Condition -Condition ((Get-Sha256 -Path $Paths.FinalPostcheck) -ceq $postcheckHash -and (Get-Sha256 -Path $Paths.Evidence) -ceq $approvedHash) -Code "approved_evidence_publish_hash_mismatch"
  return [ordered]@{ Approved = $approvedHash; Postcheck = $postcheckHash }
}

function Invoke-Phase06FinalPostcheck {
  param(
    [Parameter(Mandatory = $true)][object]$Connection,
    [Parameter(Mandatory = $true)][string]$PsqlPath,
    [Parameter(Mandatory = $true)][object]$Paths,
    [Parameter(Mandatory = $true)][object]$Manifest,
    [Parameter(Mandatory = $true)][System.Collections.ArrayList]$ApprovedResults
  )
  Set-CurrentScenario -ScenarioId "MS24_ZERO_RESIDUE"
  $postcheck = Invoke-ReadOnlyDatabasePostcheck -Connection $Connection -PsqlPath $PsqlPath -RunDirectory $Paths.Root
  Assert-Condition -Condition ($postcheck.DatabaseState -eq "POST0011") -Code "final_migration_state_rejected"
  Assert-Condition -Condition ($postcheck.Periods -eq 5) -Code "final_period_count_rejected"
  Assert-Condition -Condition ($postcheck.Activities -eq 0) -Code "final_activity_residue_rejected"
  Assert-Condition -Condition ($postcheck.AuditEvents -eq 0) -Code "final_audit_residue_rejected"
  Assert-Condition -Condition ($postcheck.OpenWorkers -eq 0) -Code "final_worker_residue_rejected"
  Assert-Condition -Condition ($postcheck.GrantedSem01AdvisoryLocks -eq 0 -and $postcheck.WaitingSem01AdvisoryLocks -eq 0 -and
    $postcheck.TotalSem01AdvisoryLocks -eq 0) -Code "final_advisory_residue_rejected"
  Assert-Condition -Condition ($postcheck.TransientWorkerSqlFiles -eq 0) -Code "final_transient_sql_residue_rejected"
  Assert-Condition -Condition ($postcheck.TemporaryObjects -eq 0) -Code "final_temporary_object_residue_rejected"
  Assert-Condition -Condition ($postcheck.FixturePeriods -eq 0) -Code "final_fixture_period_residue_rejected"
  Assert-Condition -Condition ($postcheck.FunctionInventoryCount -eq 18 -and $postcheck.FunctionInventoryValid) -Code "final_function_inventory_rejected"
  Assert-Condition -Condition ($postcheck.ExpectedTriggerMatchCount -eq 10 -and $postcheck.TriggerInventoryValid) -Code "final_trigger_inventory_rejected"
  Assert-Condition -Condition ($postcheck.AuditConstraintCount -eq 7 -and $postcheck.AuditConstraintInventoryValid) -Code "final_audit_constraint_inventory_rejected"
  Assert-Condition -Condition ($postcheck.TableSecurityValid -and $postcheck.RoutineAclValid) -Code "final_acl_rls_contract_rejected"
  Assert-Condition -Condition ($postcheck.CompleteTriggerInventoryValid -and $postcheck.ActivitiesConstraintInventoryValid -and
    $postcheck.PeriodConstraintInventoryValid -and $postcheck.CompleteAuditConstraintInventoryValid -and $postcheck.CompleteIndexInventoryValid -and
    $postcheck.TableAclContractValid -and $postcheck.RlsContractValid -and $postcheck.PolicyContractValid) -Code "final_exact_inventory_contract_rejected"
  Assert-Condition -Condition ($postcheck.NonexistentHelperCount -eq 0) -Code "final_nonexistent_helper_rejected"
  Assert-Condition -Condition ($postcheck.CalendarLockHelperCount -eq 1) -Code "final_calendar_lock_helper_missing"
  Assert-Condition -Condition ([string]$Manifest.RunStatus -ceq "running" -and [string]$Manifest.ActivePhase -ceq "PHASE_06_FINAL_POSTCHECK" -and [string]$Manifest.ActiveScenario -ceq "MS24_ZERO_RESIDUE") -Code "final_manifest_active_state_rejected"
  Assert-Condition -Condition (-not (Test-Path -LiteralPath $Paths.Failure -PathType Leaf)) -Code "final_rejected_evidence_rejected"
  Assert-Condition -Condition (-not (Test-Path -LiteralPath $Paths.Evidence -PathType Leaf)) -Code "final_existing_approved_evidence_rejected"
  Assert-FingerprintPreserved -Observed $postcheck -Expected $Manifest.BaselineFingerprint
  Assert-FingerprintPreserved -Observed $postcheck -Expected $Manifest.Post0011Fingerprint -IncludeResolver -IncludeBoundaryContract
  Assert-ProtectedArtifacts
  Assert-RepositoryState
  $ms24 = New-ScenarioResult -ScenarioId "MS24_ZERO_RESIDUE" -Outcome "complete_fingerprint_and_zero_residue" -Assertions ([ordered]@{
    CompleteCanonicalPeriodHashPreserved = ($postcheck.PeriodHash -eq $Manifest.BaselineFingerprint.PeriodHash)
    FixturePeriodsZero = ($postcheck.FixturePeriods -eq 0)
    ExactAuthorityHashPreserved = ($postcheck.AuthorityHash -eq $Manifest.BaselineFingerprint.AuthorityHash)
    ExactAssignmentHashPreserved = ($postcheck.AssignmentHash -eq $Manifest.BaselineFingerprint.AssignmentHash)
    ResolverAndBoundaryContractPreserved = ($postcheck.ResolverHash -eq $Manifest.Post0011Fingerprint.ResolverHash -and $postcheck.BoundaryContractHash -eq $Manifest.Post0011Fingerprint.BoundaryContractHash)
    ExactFunctionInventoryPreserved = ($postcheck.FunctionInventoryCount -eq 18 -and $postcheck.FunctionInventoryHash -eq $Manifest.Post0011Fingerprint.FunctionInventoryHash)
    ExactTriggerInventoryPreserved = ($postcheck.ExpectedTriggerMatchCount -eq 10 -and $postcheck.TriggerInventoryHash -eq $Manifest.Post0011Fingerprint.TriggerInventoryHash)
    ExactConstraintsIndexesRlsAndAclPreserved = ($postcheck.ConstraintInventoryHash -eq $Manifest.Post0011Fingerprint.ConstraintInventoryHash -and $postcheck.IndexInventoryHash -eq $Manifest.Post0011Fingerprint.IndexInventoryHash -and $postcheck.TableSecurityHash -eq $Manifest.Post0011Fingerprint.TableSecurityHash -and $postcheck.RoutineAclHash -eq $Manifest.Post0011Fingerprint.RoutineAclHash)
    RealCalendarLockHelperPresent = ($postcheck.NonexistentHelperCount -eq 0 -and $postcheck.CalendarLockHelperCount -eq 1)
    FixtureActivitiesZero = ($postcheck.Activities -eq 0)
    NewPeriodAuditEventsZero = ($postcheck.AuditEvents -eq 0)
    OpenWorkersZero = ($postcheck.OpenWorkers -eq 0)
    GrantedAdvisoryLocksZero = ($postcheck.GrantedSem01AdvisoryLocks -eq 0)
    WaitingAdvisoryLocksZero = ($postcheck.WaitingSem01AdvisoryLocks -eq 0)
    TotalAdvisoryLocksZero = ($postcheck.TotalSem01AdvisoryLocks -eq 0)
    TransientWorkerSqlFilesZero = ($postcheck.TransientWorkerSqlFiles -eq 0)
    TemporaryDatabaseObjectsZero = ($postcheck.TemporaryObjects -eq 0)
    RepositoryAndProtectedSourcesClean = $true
  })
  Approve-ScenarioResult -ApprovedResults $ApprovedResults -Manifest $Manifest -Paths $Paths -Result $ms24
  Assert-Condition -Condition ([string]$Manifest.RunStatus -ceq "running" -and [string]$Manifest.CompletedPhase -ceq "PHASE_05_RUNTIME_MATRIX" -and [string]$Manifest.ActivePhase -ceq "PHASE_06_FINAL_POSTCHECK" -and $null -eq $Manifest.ActiveScenario) -Code "final_manifest_evidence_pending_state_rejected"
  Assert-Condition -Condition ($ApprovedResults.Count -eq 24 -and @($ApprovedResults | ForEach-Object { $_.Id } | Sort-Object -Unique).Count -eq 24) -Code "final_scenario_result_set_rejected"
  $postcheckLines = @(
    "HARNESS_VERSION|$($script:HarnessVersion)",
    "TARGET_CLASS|DISPOSABLE_LAB",
    "DATABASE_STATE|$($postcheck.DatabaseState)",
    "CANONICAL_PERIOD_ROWS|$($postcheck.Periods)",
    "CANONICAL_PERIOD_FINGERPRINT|PRESERVED",
    "EXACT_AUTHORITY_FINGERPRINT|PRESERVED",
    "EXACT_ASSIGNMENT_FINGERPRINT|PRESERVED",
    "POST0011_BOUNDARY_FINGERPRINT|PRESERVED",
    "FIXTURE_ACTIVITIES|$($postcheck.Activities)",
    "PERIOD_AUDIT_EVENTS|$($postcheck.AuditEvents)",
    "OPEN_WORKERS|$($postcheck.OpenWorkers)",
    "GRANTED_SEM01_ADVISORY_LOCKS|$($postcheck.GrantedSem01AdvisoryLocks)",
    "WAITING_SEM01_ADVISORY_LOCKS|$($postcheck.WaitingSem01AdvisoryLocks)",
    "TOTAL_SEM01_ADVISORY_LOCKS|$($postcheck.TotalSem01AdvisoryLocks)",
    "TRANSIENT_WORKER_SQL_FILES|$($postcheck.TransientWorkerSqlFiles)",
    "TEMPORARY_DATABASE_OBJECTS|$($postcheck.TemporaryObjects)",
    "FINAL_POSTCHECK|APPROVED"
  )
  Assert-Condition -Condition (-not (Test-ForbiddenEvidence -Lines $postcheckLines)) -Code "final_postcheck_sanitization_rejected"
  $postcheckContent = ($postcheckLines -join "`n") + "`n"
  $evidenceLines = Get-ApprovedEvidenceLines -Manifest $Manifest -ApprovedResults $ApprovedResults
  Assert-Condition -Condition (-not (Test-ForbiddenEvidence -Lines $evidenceLines)) -Code "approved_evidence_sanitization_rejected"
  $evidenceContent = ($evidenceLines -join "`n") + "`n"
  $pidFilePids = @(Get-WorkerPidManifestValues -RunDirectory $Paths.Root)
  Assert-WorkerPidSetsAgree -ManifestPids @($Manifest.ActiveWorkerPids) -PidFilePids $pidFilePids
  Assert-Condition -Condition (@($Manifest.ActiveWorkerPids).Count -eq 0 -and $pidFilePids.Count -eq 0) -Code "finalization_workers_active"
  Remove-ApprovedTransientFiles -Paths $Paths
  [void](Publish-ApprovedEvidencePair -Paths $Paths -PostcheckContent $postcheckContent -ApprovedContent $evidenceContent)
  $actualApprovedHash = Get-Sha256 -Path $Paths.Evidence
  $actualPostcheckHash = Get-Sha256 -Path $Paths.FinalPostcheck
  $terminalManifest = Copy-ManifestRecord -Manifest $Manifest
  $terminalManifest.CompletedPhase = "PHASE_06_FINAL_POSTCHECK"
  $terminalManifest.ExpectedDatabaseState = "POST0011"
  $terminalManifest.ExpectedDiagnosticCounts = Get-ExpectedDiagnosticCountsForPhase -Phase "PHASE_06_FINAL_POSTCHECK"
  $terminalManifest.ExpectedActivityFixture = $null
  $terminalManifest.InstallationFixtureId = $null
  $terminalManifest.ActiveWorkerPids = @()
  $terminalManifest.ActivePhase = $null
  $terminalManifest.ActiveScenario = $null
  $terminalManifest.RunStatus = "approved"
  $terminalManifest.EvidenceHashes = [ordered]@{ Approved = $actualApprovedHash; Postcheck = $actualPostcheckHash }
  $terminalArtifacts = Get-TerminalArtifactInventory -Paths $Paths
  [void](Assert-ManifestRecord -Manifest $terminalManifest -ExpectedRunId ([string]$terminalManifest.RunId) -HasApprovedEvidence $true -HasFinalPostcheckEvidence $true `
    -FinalPostcheckMarkerValid $terminalArtifacts.ApprovedPostcheckMarkerValid -TotalPublishingArtifacts $terminalArtifacts.TotalPublishingArtifacts `
    -ApprovedEvidenceHash $actualApprovedHash -FinalPostcheckEvidenceHash $actualPostcheckHash)
  Write-Manifest -Paths $Paths -Manifest $terminalManifest
  return Read-Manifest -Paths $Paths
}

function Publish-FailurePostcheck {
  param(
    [Parameter(Mandatory = $true)][object]$Paths,
    [Parameter(Mandatory = $true)][string]$Content
  )
  Assert-Condition -Condition (-not (Test-Path -LiteralPath $Paths.FinalPostcheck -PathType Leaf)) -Code "failure_postcheck_conflicts_with_approved"
  Assert-Condition -Condition (-not (Test-Path -LiteralPath $Paths.FailurePostcheck -PathType Leaf)) -Code "failure_postcheck_already_exists"
  $temporary = $Paths.FailurePostcheck + ".publishing"
  Assert-Condition -Condition (-not (Test-Path -LiteralPath $temporary -PathType Leaf)) -Code "failure_postcheck_temporary_exists"
  Write-ExternalUtf8File -Path $temporary -Content $Content -Exclusive
  $expectedHash = Get-Sha256 -Path $temporary
  Move-Item -LiteralPath $temporary -Destination $Paths.FailurePostcheck
  Assert-Condition -Condition ((Get-Sha256 -Path $Paths.FailurePostcheck) -ceq $expectedHash) -Code "failure_postcheck_publish_hash_mismatch"
  $inventory = Get-TerminalArtifactInventory -Paths $Paths
  Assert-Condition -Condition $inventory.FailurePostcheckMarkerValid -Code "failure_postcheck_marker_rejected"
  return $true
}

function Publish-RejectedEvidence {
  param(
    [Parameter(Mandatory = $true)][object]$Paths,
    [Parameter(Mandatory = $true)][object]$Manifest,
    [Parameter(Mandatory = $true)][string]$FailurePhase,
    [Parameter(Mandatory = $true)][string]$FailureScenario,
    [Parameter(Mandatory = $true)][string]$FailureClass,
    [Parameter(Mandatory = $true)][string]$FailureCode,
    [Parameter(Mandatory = $true)][string]$ObservedState,
    [Parameter(Mandatory = $true)][bool]$FailurePostcheckRecorded
  )
  Assert-Condition -Condition ($FailureScenario -ceq "NONE" -or $FailureScenario -in @($script:RequiredScenarios | ForEach-Object { $_.Id })) -Code "failure_scenario_rejected"
  Assert-Condition -Condition ([string]$Manifest.RunStatus -cne "approved") -Code "rejected_evidence_manifest_state_rejected"
  $initialArtifacts = Get-TerminalArtifactInventory -Paths $Paths
  Assert-Condition -Condition (-not (Test-ApprovedFinalizationStarted -Inventory $initialArtifacts)) -Code "rejected_evidence_conflicts_with_approved"
  Assert-Condition -Condition ($initialArtifacts.TotalPublishingArtifacts -eq 0) -Code "rejected_evidence_publication_conflict"
  Assert-Condition -Condition (-not (Test-Path -LiteralPath $Paths.Failure -PathType Leaf)) -Code "rejected_evidence_already_exists"
  $lines = @(
    "HARNESS_VERSION|$($script:HarnessVersion)",
    "SOURCE_HEAD|$($Manifest.SourceHead)",
    "FAILURE_PHASE|$FailurePhase",
    "FAILURE_SCENARIO|$FailureScenario",
    "FAILURE_CLASS|$FailureClass",
    "FAILURE_CODE|$FailureCode",
    "ATTEMPT_NUMBER|$($Manifest.AttemptNumber)",
    "DEADLOCK_40P01|$([bool]($FailureCode -eq 'postgres_deadlock_40P01'))",
    "EXPECTED_DATABASE_PHASE|$($Manifest.ExpectedDatabaseState)",
    "OBSERVED_DATABASE_PHASE|$ObservedState",
    $(if ($FailurePostcheckRecorded) { "FAILURE_POSTCHECK|RECORDED" } else { "FAILURE_POSTCHECK|NOT_RECORDED" }),
    "SEM01_0011_MULTISESSION|REJECTED|$FailureCode"
  )
  Assert-Condition -Condition (-not (Test-ForbiddenEvidence -Lines $lines)) -Code "rejected_evidence_sanitization_rejected"
  $temporary = $Paths.Failure + ".publishing"
  Assert-Condition -Condition (-not (Test-Path -LiteralPath $temporary)) -Code "rejected_evidence_temporary_exists"
  Write-ExternalUtf8File -Path $temporary -Content (($lines -join "`n") + "`n") -Exclusive
  $actualHash = Get-Sha256 -Path $temporary
  Move-Item -LiteralPath $temporary -Destination $Paths.Failure
  Assert-Condition -Condition ((Get-Sha256 -Path $Paths.Failure) -ceq $actualHash) -Code "rejected_evidence_publish_hash_mismatch"
  return Get-Sha256 -Path $Paths.Failure
}

function Complete-RejectedManifest {
  param(
    [Parameter(Mandatory = $true)][object]$Paths,
    [Parameter(Mandatory = $true)][object]$Manifest,
    [Parameter(Mandatory = $true)][string]$FailureCode,
    [Parameter(Mandatory = $true)][string]$RejectedEvidenceHash
  )
  Assert-Condition -Condition ((Get-Sha256 -Path $Paths.Failure) -ceq $RejectedEvidenceHash) -Code "rejected_evidence_actual_hash_mismatch"
  $terminalManifest = Copy-ManifestRecord -Manifest $Manifest
  $terminalManifest.FailureCode = $FailureCode
  $terminalManifest.RunStatus = "rejected"
  $terminalManifest.EvidenceHashes = [ordered]@{ Rejected = $RejectedEvidenceHash }
  $terminalArtifacts = Get-TerminalArtifactInventory -Paths $Paths
  [void](Assert-ManifestRecord -Manifest $terminalManifest -ExpectedRunId ([string]$terminalManifest.RunId) -HasRejectedEvidence $true `
    -HasFailurePostcheckEvidence $terminalArtifacts.FailurePostcheckExists -FailurePostcheckMarkerValid $terminalArtifacts.FailurePostcheckMarkerValid `
    -TotalPublishingArtifacts $terminalArtifacts.TotalPublishingArtifacts -RejectedEvidenceHash $RejectedEvidenceHash)
  Write-Manifest -Paths $Paths -Manifest $terminalManifest
  return Read-Manifest -Paths $Paths
}

function Assert-FinalApprovedState {
  param([Parameter(Mandatory = $true)][object]$Paths)
  Assert-Condition -Condition (Test-Path -LiteralPath $Paths.Evidence -PathType Leaf) -Code "final_approved_evidence_missing"
  Assert-Condition -Condition (Test-Path -LiteralPath $Paths.FinalPostcheck -PathType Leaf) -Code "final_postcheck_evidence_missing"
  Assert-Condition -Condition (-not (Test-Path -LiteralPath $Paths.FailurePostcheck -PathType Leaf)) -Code "final_failure_postcheck_present"
  Assert-Condition -Condition (-not (Test-Path -LiteralPath $Paths.Failure -PathType Leaf)) -Code "final_rejected_evidence_present"
  $persisted = Read-Manifest -Paths $Paths
  Assert-Condition -Condition ([string]$persisted.RunStatus -ceq "approved" -and [string]$persisted.CompletedPhase -ceq "PHASE_06_FINAL_POSTCHECK") -Code "final_approved_manifest_state_rejected"
  Assert-Condition -Condition ($null -eq $persisted.ActivePhase -and $null -eq $persisted.ActiveScenario -and @($persisted.ActiveWorkerPids).Count -eq 0) -Code "final_approved_manifest_activity_rejected"
  $expectedIds = @($script:RequiredScenarios | Sort-Object Ordinal | ForEach-Object { $_.Id })
  $observedIds = @($persisted.ApprovedScenarioResults | ForEach-Object { [string]$_.Id })
  Assert-Condition -Condition ($observedIds.Count -eq 24 -and ((@($observedIds | Sort-Object) -join "|") -ceq (@($expectedIds | Sort-Object) -join "|"))) -Code "final_approved_scenario_set_rejected"
  foreach ($result in @($persisted.ApprovedScenarioResults)) {
    $assertions = @(Get-AssertionProperties -Assertions $result.Assertions)
    Assert-Condition -Condition ($assertions.Count -gt 0 -and @($assertions | Where-Object { $_.Value -ne $true }).Count -eq 0) -Code "final_approved_assertion_rejected"
  }
  Assert-Condition -Condition ([string]$persisted.EvidenceHashes.Approved -ceq (Get-Sha256 -Path $Paths.Evidence) -and [string]$persisted.EvidenceHashes.Postcheck -ceq (Get-Sha256 -Path $Paths.FinalPostcheck)) -Code "final_approved_actual_hash_mismatch"
  return $persisted
}

function Invoke-ValidateOnlyMode {
  Invoke-Phase00Validate -AllowPreparationDelta
  Write-Output "LOCAL_REPOSITORY|APPROVED"
  Write-Output "SOURCE_HEAD|$(Get-SourceHead)"
  Write-Output "REMOTE_CONNECTION|NOT_ATTEMPTED"
  Write-Output "DATABASE_CREDENTIAL_PROMPT|NOT_ATTEMPTED"
  Write-Output "MULTISESSION_EXECUTION|NOT_ATTEMPTED"
  Write-Output "SCENARIO_CONTRACT|24"
  Write-Output "HARNESS_STATIC_VALIDATION|APPROVED"
}

function Invoke-ReadOnlyProbeMode {
  Invoke-Phase00Validate
  $answer = Read-Host "Escribe exactamente: $($script:ProbeConfirmationPhrase)"
  Assert-Condition -Condition ($answer -ceq $script:ProbeConfirmationPhrase) -Code "probe_confirmation_rejected"
  $psqlPath = Resolve-PsqlExecutable
  Assert-PsqlVersion -PsqlPath $psqlPath
  $connection = $null
  try {
    $connection = ConvertFrom-HiddenConnectionInput
    [System.IO.Directory]::CreateDirectory($script:EvidenceRoot) | Out-Null
    $identifier = New-RunIdentifier
    $paths = New-RunPaths -Identifier $identifier
    [System.IO.Directory]::CreateDirectory($paths.Root) | Out-Null
    $baseline = Invoke-ReadOnlyBaseline -Connection $connection -PsqlPath $psqlPath -RunDirectory $paths.Root -ExpectedState "POST0010"
    $lines = @(
      "HARNESS_VERSION|$($script:HarnessVersion)",
      "TARGET_CLASS|DISPOSABLE_LAB",
      "DATABASE_STATE|POST0010",
      "CANONICAL_PERIODS|$($baseline.Periods)",
      "EXACT_SYNTHETIC_AUTHORITIES|$($baseline.ExactAuthorities)",
      "MS20_SYNTHETIC_NONADMIN_CANDIDATES|$($baseline.Ms20CandidateCount)",
      "MS20_CANDIDATE_SET|APPROVED",
      "READ_ONLY_PROBE|APPROVED"
    )
    Assert-Condition -Condition (-not (Test-ForbiddenEvidence -Lines $lines)) -Code "probe_evidence_sanitization_rejected"
    Write-ExternalUtf8File -Path (Join-Path $paths.Root "read-only-probe.local.txt") -Content (($lines -join "`n") + "`n") -Exclusive
    Write-Output "READ_ONLY_PROBE|APPROVED"
  }
  finally {
    Clear-ConnectionMaterial -Connection $connection
  }
}

function Invoke-PostcheckOnlyMode {
  Assert-Condition -Condition (-not [string]::IsNullOrWhiteSpace($RunId)) -Code "postcheck_run_id_required"
  Invoke-Phase00Validate
  $answer = Read-Host "Escribe exactamente: $($script:PostcheckConfirmationPhrase)"
  Assert-Condition -Condition ($answer -ceq $script:PostcheckConfirmationPhrase) -Code "postcheck_confirmation_rejected"
  $psqlPath = Resolve-PsqlExecutable
  Assert-PsqlVersion -PsqlPath $psqlPath
  $paths = New-RunPaths -Identifier $RunId
  $manifest = Read-ManifestForDiagnostic -Paths $paths
  $connection = $null
  try {
    $connection = ConvertFrom-HiddenConnectionInput
    $postcheck = Invoke-ReadOnlyDatabasePostcheck -Connection $connection -PsqlPath $psqlPath -RunDirectory $paths.Root
    $pidFilePids = @(Get-WorkerPidManifestValues -RunDirectory $paths.Root)
    $workerPidSourcesMatch = ((@($manifest.ActiveWorkerPids | Sort-Object) -join "|") -ceq (@($pidFilePids | Sort-Object) -join "|"))
    $fingerprintAvailable = $postcheck.FingerprintAvailable -eq $true
    $baselineAvailable = $fingerprintAvailable -and $null -ne $manifest.BaselineFingerprint
    $expectedCountsAvailable = $null -ne $manifest.ExpectedDiagnosticCounts
    $stateMatches = $postcheck.DatabaseState -ceq [string]$manifest.ExpectedDatabaseState
    $periodMatches = $baselineAvailable -and $postcheck.PeriodHash -ceq [string]$manifest.BaselineFingerprint.PeriodHash
    $authorityMatches = $baselineAvailable -and $postcheck.AuthorityHash -ceq [string]$manifest.BaselineFingerprint.AuthorityHash
    $assignmentMatches = $baselineAvailable -and $postcheck.AssignmentHash -ceq [string]$manifest.BaselineFingerprint.AssignmentHash
    $ms20CandidateSetMatches = $baselineAvailable -and
      $postcheck.Ms20CandidateCount -eq [int]$manifest.BaselineFingerprint.Ms20CandidateCount -and
      $postcheck.Ms20CandidateSetHash -ceq [string]$manifest.BaselineFingerprint.Ms20CandidateSetHash
    $expectedResolver = if ([string]$manifest.ExpectedDatabaseState -ceq "POST0011") { $manifest.Post0011Fingerprint } else { $manifest.BaselineFingerprint }
    $resolverApplicable = $fingerprintAvailable -and $null -ne $expectedResolver
    $resolverMatches = $resolverApplicable -and $postcheck.ResolverHash -ceq [string]$expectedResolver.ResolverHash
    $expectedBoundary = if ([string]$manifest.ExpectedDatabaseState -ceq "POST0011") { $manifest.Post0011Fingerprint } else { $manifest.BaselineFingerprint }
    $boundaryApplicable = $fingerprintAvailable -and $null -ne $expectedBoundary
    $boundaryMatches = $boundaryApplicable -and
      $postcheck.BoundaryContractHash -ceq [string]$expectedBoundary.BoundaryContractHash -and
      $postcheck.FunctionInventoryCount -eq [int]$expectedBoundary.FunctionInventoryCount -and
      $postcheck.FunctionInventoryHash -ceq [string]$expectedBoundary.FunctionInventoryHash -and
      $postcheck.ExpectedTriggerMatchCount -eq [int]$expectedBoundary.ExpectedTriggerMatchCount -and
      $postcheck.TriggerInventoryHash -ceq [string]$expectedBoundary.TriggerInventoryHash -and
      $postcheck.ConstraintInventoryHash -ceq [string]$expectedBoundary.ConstraintInventoryHash -and
      $postcheck.IndexInventoryHash -ceq [string]$expectedBoundary.IndexInventoryHash -and
      $postcheck.TableSecurityHash -ceq [string]$expectedBoundary.TableSecurityHash -and
      $postcheck.RoutineAclHash -ceq [string]$expectedBoundary.RoutineAclHash -and
      $postcheck.FunctionInventoryValid -and $postcheck.TriggerInventoryValid -and
      $postcheck.AuditConstraintInventoryValid -and $postcheck.TableSecurityValid -and $postcheck.RoutineAclValid -and
      $postcheck.CompleteTriggerInventoryValid -and $postcheck.ActivitiesConstraintInventoryValid -and
      $postcheck.PeriodConstraintInventoryValid -and $postcheck.CompleteAuditConstraintInventoryValid -and
      $postcheck.CompleteIndexInventoryValid -and $postcheck.TableAclContractValid -and $postcheck.RlsContractValid -and $postcheck.PolicyContractValid -and
      $postcheck.NonexistentHelperCount -eq [int]$expectedBoundary.NonexistentHelperCount -and
      $postcheck.CalendarLockHelperCount -eq [int]$expectedBoundary.CalendarLockHelperCount
    $fixtureCountMatches = $expectedCountsAvailable -and $postcheck.FixturePeriods -eq $manifest.ExpectedDiagnosticCounts.FixturePeriods
    $activityCountMatches = $expectedCountsAvailable -and $postcheck.Activities -eq $manifest.ExpectedDiagnosticCounts.Activities
    $auditCountMatches = $expectedCountsAvailable -and $postcheck.AuditEvents -eq $manifest.ExpectedDiagnosticCounts.AuditEvents
    $workerCountMatches = $expectedCountsAvailable -and $postcheck.OpenWorkers -eq $manifest.ExpectedDiagnosticCounts.OpenWorkers
    $advisoryCountMatches = $expectedCountsAvailable -and
      $postcheck.GrantedSem01AdvisoryLocks -eq $manifest.ExpectedDiagnosticCounts.GrantedSem01AdvisoryLocks -and
      $postcheck.WaitingSem01AdvisoryLocks -eq $manifest.ExpectedDiagnosticCounts.WaitingSem01AdvisoryLocks -and
      $postcheck.TotalSem01AdvisoryLocks -eq $manifest.ExpectedDiagnosticCounts.TotalSem01AdvisoryLocks
    $transientSqlCountMatches = $expectedCountsAvailable -and $postcheck.TransientWorkerSqlFiles -eq $manifest.ExpectedDiagnosticCounts.TransientWorkerSqlFiles
    $temporaryCountMatches = $expectedCountsAvailable -and $postcheck.TemporaryObjects -eq $manifest.ExpectedDiagnosticCounts.TemporaryObjects
    $activityFixtureMatches = $null -eq $manifest.ExpectedActivityFixture
    if ($null -ne $manifest.ExpectedActivityFixture) {
      $activityFixture = Get-ActivityFixtureSnapshot -Connection $connection -PsqlPath $psqlPath -RunDirectory $paths.Root -ActivityId ([string]$manifest.ExpectedActivityFixture.Id)
      $activityFixtureMatches = $activityFixture.Activities -eq 1 -and $activityFixture.MatchingRows -eq 1 -and $activityFixture.RowFingerprint -ceq [string]$manifest.ExpectedActivityFixture.RowFingerprint
    }
    $protectedSourcesMatch = Test-ProtectedArtifactsMatch
    $terminalArtifacts = Get-TerminalArtifactInventory -Paths $paths
    $terminalClassification = Get-TerminalArtifactClassification -Inventory $terminalArtifacts -RunStatus ([string]$manifest.RunStatus)
    $evidenceContractMatches = $terminalClassification.EvidenceContractMatches
    $currentHead = Get-SourceHead
    $runIdMatches = [string]$manifest.RunId -ceq $RunId
    $sourceHeadMatches = [string]$manifest.SourceHead -ceq $currentHead
    $migrationHashMatches = [string]$manifest.MigrationSha256 -ceq (Get-Sha256 -Path $script:MigrationPath)
    $rollbackHashMatches = [string]$manifest.RollbackSha256 -ceq (Get-Sha256 -Path $script:RollbackPath)
    $harnessHashMatches = [string]$manifest.HarnessSha256 -ceq (Get-Sha256 -Path $PSCommandPath)
    $harnessVersionMatches = [string]$manifest.HarnessVersion -ceq $script:HarnessVersion
    $provenanceMatches = $runIdMatches -and $sourceHeadMatches -and $migrationHashMatches -and $rollbackHashMatches -and $harnessHashMatches -and $harnessVersionMatches
    $boundaryRequiredAndMatched = $boundaryMatches
    $clean = $fingerprintAvailable -and $stateMatches -and $postcheck.Periods -eq 5 -and $periodMatches -and $authorityMatches -and
      $assignmentMatches -and $ms20CandidateSetMatches -and $resolverMatches -and $boundaryRequiredAndMatched -and
      $fixtureCountMatches -and $activityCountMatches -and $auditCountMatches -and $workerCountMatches -and $advisoryCountMatches -and
      $transientSqlCountMatches -and $temporaryCountMatches -and
      $activityFixtureMatches -and $workerPidSourcesMatch -and $protectedSourcesMatch -and $evidenceContractMatches -and
      $terminalArtifacts.TotalPublishingArtifacts -eq 0 -and $provenanceMatches

    $stableCode = if ($null -ne $terminalClassification.StableCode) { [string]$terminalClassification.StableCode }
      elseif ($postcheck.DatabaseState -ceq "UNKNOWN" -and $null -ne $postcheck.PartialStateReason) { "partial_database_state" }
      elseif ($postcheck.DatabaseState -ceq "UNKNOWN") { "unknown_database_state" }
      elseif (-not $stateMatches) { "database_state_mismatch" }
      elseif (-not $runIdMatches) { "manifest_run_id_drift" }
      elseif (-not $sourceHeadMatches) { "manifest_source_head_drift" }
      elseif (-not $migrationHashMatches) { "manifest_migration_hash_drift" }
      elseif (-not $rollbackHashMatches) { "manifest_rollback_hash_drift" }
      elseif (-not $harnessHashMatches) { "manifest_harness_hash_drift" }
      elseif (-not $harnessVersionMatches) { "manifest_harness_version_drift" }
      elseif (-not $baselineAvailable) { "baseline_fingerprint_not_frozen" }
      elseif (-not $expectedCountsAvailable) { "diagnostic_expectations_not_frozen" }
      elseif ($postcheck.Periods -ne 5 -or -not $periodMatches) { "canonical_period_drift" }
      elseif (-not $authorityMatches) { "authority_fingerprint_drift" }
      elseif (-not $assignmentMatches) { "assignment_fingerprint_drift" }
      elseif (-not $ms20CandidateSetMatches) { "ms20_candidate_set_fingerprint_drift" }
      elseif (-not $resolverMatches) { "resolver_fingerprint_drift" }
      elseif (-not $boundaryRequiredAndMatched) { "post0011_boundary_fingerprint_drift" }
      elseif (-not $fixtureCountMatches) { "fixture_period_residue" }
      elseif (-not $activityCountMatches) { "activity_residue" }
      elseif (-not $auditCountMatches) { "audit_event_residue" }
      elseif (-not $workerCountMatches) { "open_worker_residue" }
      elseif (-not $advisoryCountMatches) { "advisory_lock_residue" }
      elseif (-not $transientSqlCountMatches) { "transient_worker_sql_residue" }
      elseif (-not $temporaryCountMatches) { "temporary_object_residue" }
      elseif (-not $workerPidSourcesMatch) { "worker_pid_sources_disagree" }
      elseif (-not $activityFixtureMatches) { "activity_fixture_drift" }
      elseif (-not $protectedSourcesMatch) { "protected_source_drift" }
      elseif (-not $evidenceContractMatches) { "approved_evidence_state_drift" }
      else { "clean" }

    $comparisons = [pscustomobject]@{
      StateMatches = $stateMatches
      BaselineAvailable = $baselineAvailable
      PeriodMatches = $periodMatches
      AuthorityMatches = $authorityMatches
      AssignmentMatches = $assignmentMatches
      Ms20CandidateSetMatches = $ms20CandidateSetMatches
      ResolverApplicable = $resolverApplicable
      ResolverMatches = $resolverMatches
      BoundaryApplicable = $boundaryApplicable
      BoundaryMatches = $boundaryMatches
      ActivityFixtureMatches = $activityFixtureMatches
      RunIdMatches = $runIdMatches
      SourceHeadMatches = $sourceHeadMatches
      MigrationHashMatches = $migrationHashMatches
      RollbackHashMatches = $rollbackHashMatches
      HarnessHashMatches = $harnessHashMatches
      HarnessVersionMatches = $harnessVersionMatches
      ProtectedSourcesMatch = $protectedSourcesMatch
      EvidenceContractMatches = $evidenceContractMatches
      PidFileCount = $pidFilePids.Count
      ApprovedPostcheckPublishing = $terminalArtifacts.ApprovedPostcheckPublishing
      ApprovedEvidencePublishing = $terminalArtifacts.ApprovedEvidencePublishing
      FailurePostcheckPublishing = $terminalArtifacts.FailurePostcheckPublishing
      RejectedEvidencePublishing = $terminalArtifacts.RejectedEvidencePublishing
      TotalPublishingArtifacts = $terminalArtifacts.TotalPublishingArtifacts
    }
    $lines = Get-PostcheckDiagnosticLines -Diagnostic $postcheck -Manifest $manifest -Comparisons $comparisons -StableCode $stableCode -Clean $clean
    Assert-Condition -Condition (-not (Test-ForbiddenEvidence -Lines $lines)) -Code "postcheck_evidence_sanitization_rejected"
    $postcheckPath = Join-Path $paths.Root ("postcheck_" + [DateTime]::UtcNow.ToString("yyyyMMdd'T'HHmmss'Z'") + ".local.txt")
    Write-ExternalUtf8File -Path $postcheckPath -Content (($lines -join "`n") + "`n") -Exclusive
    if ($clean) {
      Write-Output "POSTCHECK_ONLY|CLEAN"
    }
    else {
      Write-Output "POSTCHECK_ONLY|DRIFT_OR_RESIDUE|$stableCode"
      Throw-StableFailure -Code ("postcheck_only_drift_or_residue_" + $stableCode) -FailureClass "postcondition_rejection"
    }
  }
  finally {
    Clear-ConnectionMaterial -Connection $connection
  }
}

function Invoke-ExecuteMode {
  Invoke-Phase00Validate
  $answer = Read-Host "Escribe exactamente: $($script:ExecutionConfirmationPhrase)"
  Assert-Condition -Condition ($answer -ceq $script:ExecutionConfirmationPhrase) -Code "execute_confirmation_rejected"
  $psqlPath = Resolve-PsqlExecutable
  Assert-PsqlVersion -PsqlPath $psqlPath
  $connection = $null
  $paths = $null
  $manifest = $null
  $approvedResults = New-Object System.Collections.ArrayList
  $currentPhase = "PHASE_00_VALIDATE"
  $attemptStarted = $false
  try {
    $connection = ConvertFrom-HiddenConnectionInput
    [System.IO.Directory]::CreateDirectory($script:EvidenceRoot) | Out-Null
    if ([string]::IsNullOrWhiteSpace($RunId)) {
      $identifier = New-RunIdentifier
      $paths = New-RunPaths -Identifier $identifier
      [System.IO.Directory]::CreateDirectory($paths.Root) | Out-Null
      $manifest = New-Manifest -Identifier $identifier
      Write-Manifest -Paths $paths -Manifest $manifest
    }
    else {
      $paths = New-RunPaths -Identifier $RunId
      $manifest = Read-Manifest -Paths $paths
      $connection | Add-Member -NotePropertyName ExecutionContext -NotePropertyValue ([pscustomobject]@{ Manifest = $manifest; Paths = $paths }) -Force
      Assert-ResumeContract -Manifest $manifest -Connection $connection -PsqlPath $psqlPath -Paths $paths
      foreach ($saved in @($manifest.ApprovedScenarioResults)) {
        $assertions = [ordered]@{}
        foreach ($property in @($saved.Assertions.PSObject.Properties)) { $assertions[$property.Name] = [bool]$property.Value }
        [void]$approvedResults.Add([pscustomobject]@{ Id = [string]$saved.Id; Outcome = [string]$saved.Outcome; Assertions = $assertions; CompletedAtUtc = [string]$saved.CompletedAtUtc })
      }
    }
    if (-not (Test-ObjectProperty -Value $connection -Name "ExecutionContext")) {
      $connection | Add-Member -NotePropertyName ExecutionContext -NotePropertyValue ([pscustomobject]@{ Manifest = $manifest; Paths = $paths }) -Force
    }

    $completedIndex = [array]::IndexOf($script:PhaseOrder, [string]$manifest.CompletedPhase)
    Assert-Condition -Condition ($completedIndex -ge -1 -and $completedIndex -le 5) -Code "execute_completed_phase_rejected" -FailureClass "source_integrity_rejection"

    if ($completedIndex -lt 1) {
      $currentPhase = "PHASE_01_READ_ONLY_BASELINE"
      Start-ManifestPhase -Manifest $manifest -Paths $paths -Phase $currentPhase -IncrementAttempt:(-not $attemptStarted)
      $attemptStarted = $true
      Invoke-Phase01ReadOnlyBaseline -Connection $connection -PsqlPath $psqlPath -Paths $paths -Manifest $manifest -ApprovedResults $approvedResults
      $completedIndex = 1
    }
    if ($completedIndex -lt 2) {
      $currentPhase = "PHASE_02_INSTALLATION_MATRIX"
      Start-ManifestPhase -Manifest $manifest -Paths $paths -Phase $currentPhase -IncrementAttempt:(-not $attemptStarted)
      $attemptStarted = $true
      Clear-CurrentScenario
      $authorities = Get-SyntheticAuthorityIds -Connection $connection -PsqlPath $psqlPath -RunDirectory $paths.Root
      $authorityId = $authorities[0]
      Invoke-Phase02InstallationMatrix -Connection $connection -PsqlPath $psqlPath -Paths $paths -Manifest $manifest -ApprovedResults $approvedResults -AuthorityId $authorityId
      $completedIndex = 2
    }
    if ($completedIndex -lt 3) {
      $currentPhase = "PHASE_03_ROLLBACK_MATRIX"
      Start-ManifestPhase -Manifest $manifest -Paths $paths -Phase $currentPhase -IncrementAttempt:(-not $attemptStarted)
      $attemptStarted = $true
      Clear-CurrentScenario
      $authorities = Get-SyntheticAuthorityIds -Connection $connection -PsqlPath $psqlPath -RunDirectory $paths.Root
      $authorityId = $authorities[0]
      Invoke-Phase03RollbackMatrix -Connection $connection -PsqlPath $psqlPath -Paths $paths -Manifest $manifest -ApprovedResults $approvedResults -AuthorityId $authorityId
      $completedIndex = 3
    }
    if ($completedIndex -lt 4) {
      $currentPhase = "PHASE_04_REAPPLY_0011"
      Start-ManifestPhase -Manifest $manifest -Paths $paths -Phase $currentPhase -IncrementAttempt:(-not $attemptStarted)
      $attemptStarted = $true
      Clear-CurrentScenario
      Invoke-Phase04Reapply0011 -Connection $connection -PsqlPath $psqlPath -Paths $paths -Manifest $manifest -ApprovedResults $approvedResults
      $completedIndex = 4
    }
    if ($completedIndex -lt 5) {
      $currentPhase = "PHASE_05_RUNTIME_MATRIX"
      Start-ManifestPhase -Manifest $manifest -Paths $paths -Phase $currentPhase -IncrementAttempt:(-not $attemptStarted)
      $attemptStarted = $true
      Clear-CurrentScenario
      $authorities = Get-SyntheticAuthorityIds -Connection $connection -PsqlPath $psqlPath -RunDirectory $paths.Root
      $authorityId = $authorities[0]
      Invoke-Phase05RuntimeMatrix -Connection $connection -PsqlPath $psqlPath -Paths $paths -Manifest $manifest -ApprovedResults $approvedResults -AuthorityId $authorityId
      $completedIndex = 5
    }
    if ($completedIndex -lt 6) {
      $currentPhase = "PHASE_06_FINAL_POSTCHECK"
      Start-ManifestPhase -Manifest $manifest -Paths $paths -Phase $currentPhase -IncrementAttempt:(-not $attemptStarted)
      $attemptStarted = $true
      Clear-CurrentScenario
      $manifest = Invoke-Phase06FinalPostcheck -Connection $connection -PsqlPath $psqlPath -Paths $paths -Manifest $manifest -ApprovedResults $approvedResults
    }
    $manifest = Assert-FinalApprovedState -Paths $paths
    Write-Output "SEM01_0011_MULTISESSION|APPROVED"
  }
  catch {
    $caughtError = $_
    $candidateCode = if ([string]::IsNullOrWhiteSpace($caughtError.Exception.Message)) { "unexpected_harness_failure" } else { $caughtError.Exception.Message }
    $failureCode = if ($candidateCode -match '^[a-z0-9]+(?:_[a-z0-9]+)*(?:_(?:40P01|55P03|25000|23514|42501))?$') { $candidateCode } else { "unexpected_harness_failure" }
    $failureClass = if ($caughtError.Exception.Data.Contains("FailureClass")) { [string]$caughtError.Exception.Data["FailureClass"] } else { "postcondition_rejection" }
    $failureScenarioResult = Invoke-SecondaryFailureOperation -Operation { return Get-FailureScenario }
    $failureScenario = if ($failureScenarioResult.Succeeded) { [string]$failureScenarioResult.Value } else { "NONE" }
    if (-not $failureScenarioResult.Succeeded) { Write-Output "SECONDARY_FINALIZATION|FAILURE_SCENARIO|FAILED" }
    if ($null -ne $manifest -and $null -ne $paths) {
      $terminalSnapshotResult = Invoke-SecondaryFailureOperation -Operation { return Get-TerminalArtifactInventory -Paths $paths }
      if (-not $terminalSnapshotResult.Succeeded) { Write-Output "SECONDARY_FINALIZATION|TERMINAL_SNAPSHOT|FAILED" }
      if ($terminalSnapshotResult.Succeeded -and -not (Test-ApprovedFinalizationStarted -Inventory $terminalSnapshotResult.Value)) {
        $observed = "UNKNOWN"
        $failurePostcheckRecorded = $false
        $failurePostcheckResult = Invoke-SecondaryFailureOperation -Operation {
          $failurePostcheck = Invoke-ReadOnlyDatabasePostcheck -Connection $connection -PsqlPath $psqlPath -RunDirectory $paths.Root
          $failurePostcheckLines = @(
            "HARNESS_VERSION|$($script:HarnessVersion)",
            "TARGET_CLASS|DISPOSABLE_LAB",
            "DATABASE_STATE|$($failurePostcheck.DatabaseState)",
            "CANONICAL_PERIOD_ROWS|$($failurePostcheck.Periods)",
            "FIXTURE_ACTIVITIES|$($failurePostcheck.Activities)",
            "PERIOD_AUDIT_EVENTS|$($failurePostcheck.AuditEvents)",
            "OPEN_WORKERS|$($failurePostcheck.OpenWorkers)",
            "GRANTED_SEM01_ADVISORY_LOCKS|$($failurePostcheck.GrantedSem01AdvisoryLocks)",
            "WAITING_SEM01_ADVISORY_LOCKS|$($failurePostcheck.WaitingSem01AdvisoryLocks)",
            "TOTAL_SEM01_ADVISORY_LOCKS|$($failurePostcheck.TotalSem01AdvisoryLocks)",
            "TRANSIENT_WORKER_SQL_FILES|$($failurePostcheck.TransientWorkerSqlFiles)",
            "TEMPORARY_DATABASE_OBJECTS|$($failurePostcheck.TemporaryObjects)",
            "FAILURE_POSTCHECK|RECORDED"
          )
          Assert-Condition -Condition (-not (Test-ForbiddenEvidence -Lines $failurePostcheckLines)) -Code "failure_postcheck_sanitization_rejected"
          [void](Publish-FailurePostcheck -Paths $paths -Content (($failurePostcheckLines -join "`n") + "`n"))
          return [pscustomobject]@{ ObservedState = [string]$failurePostcheck.DatabaseState }
        }
        if ($failurePostcheckResult.Succeeded) {
          $failurePostcheckRecorded = $true
          $observed = [string]$failurePostcheckResult.Value.ObservedState
        }
        else {
          Write-Output "SECONDARY_FINALIZATION|FAILURE_POSTCHECK|FAILED"
          $failurePostcheckInventoryResult = Invoke-SecondaryFailureOperation -Operation { return Get-TerminalArtifactInventory -Paths $paths }
          if ($failurePostcheckInventoryResult.Succeeded -and $failurePostcheckInventoryResult.Value.FailurePostcheckMarkerValid) {
            $failurePostcheckRecorded = $true
          }
        }

        $rejectedEvidenceResult = Invoke-SecondaryFailureOperation -Operation {
          return Publish-RejectedEvidence -Paths $paths -Manifest $manifest -FailurePhase $currentPhase -FailureScenario $failureScenario `
            -FailureClass $failureClass -FailureCode $failureCode -ObservedState $observed -FailurePostcheckRecorded $failurePostcheckRecorded
        }
        if ($rejectedEvidenceResult.Succeeded) {
          $rejectedManifestResult = Invoke-SecondaryFailureOperation -Operation {
            return Complete-RejectedManifest -Paths $paths -Manifest $manifest -FailureCode $failureCode -RejectedEvidenceHash ([string]$rejectedEvidenceResult.Value)
          }
          if ($rejectedManifestResult.Succeeded) { $manifest = $rejectedManifestResult.Value }
          else { Write-Output "SECONDARY_FINALIZATION|REJECTED_MANIFEST|FAILED" }
        }
        else { Write-Output "SECONDARY_FINALIZATION|REJECTED_EVIDENCE|FAILED" }
      }
    }
    throw $caughtError
  }
  finally {
    Clear-ConnectionMaterial -Connection $connection
  }
}

$modeCount = @($ValidateOnly.IsPresent, $ReadOnlyProbeOnly.IsPresent, $Execute.IsPresent, $PostcheckOnly.IsPresent) |
  Where-Object { $_ } |
  Measure-Object |
  Select-Object -ExpandProperty Count
if ($modeCount -eq 0) {
  $ValidateOnly = $true
}
elseif ($modeCount -ne 1) {
  Throw-StableFailure -Code "execution_mode_rejected"
}
if (-not [string]::IsNullOrWhiteSpace($RunId) -and -not ($Execute -or $PostcheckOnly)) {
  Throw-StableFailure -Code "run_id_mode_rejected"
}

if ($ValidateOnly) {
  Invoke-ValidateOnlyMode
  return
}
if ($ReadOnlyProbeOnly) {
  Invoke-ReadOnlyProbeMode
  return
}
if ($PostcheckOnly) {
  Invoke-PostcheckOnlyMode
  return
}
if ($Execute) {
  Invoke-ExecuteMode
  return
}

Throw-StableFailure -Code "execution_mode_rejected"
