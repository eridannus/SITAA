import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { TextDecoder } from "node:util";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const harnessPath = path.join(root, "scripts", "sem01_0011_run_multisession.ps1");
const canonicalBoundaryPath = path.join(root, "scripts", "b3a_matrix_run_hosted_auth_concurrency_boundaries.ps1");
const migrationPath = path.join(root, "supabase", "migrations", "0011_academic_period_administration.sql");

const readStrictUtf8 = (target) => {
  const bytes = fs.readFileSync(target);
  const decoded = new TextDecoder("utf-8", { fatal: true }).decode(bytes);
  assert.ok(decoded.length > 0, `${path.basename(target)} no puede estar vacío`);
  return decoded.replace(/^\uFEFF/, "").replace(/\r\n?/g, "\n");
};

const harnessBytes = fs.readFileSync(harnessPath);
assert.deepEqual([...harnessBytes.subarray(0, 3)], [0xef, 0xbb, 0xbf], "El arnés requiere BOM UTF-8");
const harness = readStrictUtf8(harnessPath);
const canonicalBoundary = readStrictUtf8(canonicalBoundaryPath);
const migration = readStrictUtf8(migrationPath);
assert.match(harness, /\$script:HarnessVersion = "2026-08-12-sem01-0011-multisession-v20"/);

const occurrences = (source, pattern) => [...source.matchAll(pattern)].length;
const extractFunction = (source, name) => {
  const startPattern = new RegExp(`^function\\s+${name.replaceAll("-", "\\-")}\\s*\\{`, "m");
  const match = startPattern.exec(source);
  assert.ok(match, `Falta la función ${name}`);
  const start = match.index;
  const next = source.indexOf("\nfunction ", start + match[0].length);
  const end = next >= 0 ? next : source.length;
  assert.ok(end > start, `No se pudo delimitar ${name}`);
  return source.slice(start, end);
};
const extractParamBlock = (functionSource, name) => {
  const start = functionSource.indexOf("param(");
  assert.ok(start >= 0, `${name} no declara param`);
  let depth = 0;
  for (let index = start + "param".length; index < functionSource.length; index += 1) {
    if (functionSource[index] === "(") depth += 1;
    if (functionSource[index] === ")") {
      depth -= 1;
      if (depth === 0) return functionSource.slice(start, index + 1);
    }
  }
  assert.fail(`No se pudo delimitar param de ${name}`);
};
const assertNamedArgumentsDeclared = (callerSource, calleeName, calleeParamBlock) => {
  const declared = new Set([...calleeParamBlock.matchAll(/\$([A-Za-z][A-Za-z0-9]*)/g)].map((match) => match[1]));
  const calls = callerSource.split("\n").filter((line) => line.includes(calleeName));
  assert.ok(calls.length > 0, `No se encontró llamada a ${calleeName}`);
  for (const call of calls) {
    for (const match of call.matchAll(/(?:^|\s)-([A-Za-z][A-Za-z0-9]*)\b/g)) {
      assert.ok(declared.has(match[1]), `${calleeName} no declara el argumento nombrado ${match[1]}`);
    }
  }
};
const extractMarkedBlock = (source, begin, end) => {
  const start = source.indexOf(begin);
  const finish = source.indexOf(end, start + begin.length);
  assert.ok(start >= 0, `Falta ${begin}`);
  assert.ok(finish > start, `Falta ${end}`);
  return source.slice(start + begin.length, finish);
};
const requireInOrder = (source, needles, message) => {
  let cursor = -1;
  for (const needle of needles) {
    const index = source.indexOf(needle, cursor + 1);
    assert.ok(index > cursor, `${message}: falta o está fuera de orden ${needle}`);
    cursor = index;
  }
};
const expectReject = (label, callback) => assert.throws(callback, undefined, `Fixture negativa aceptada: ${label}`);

const parseInstallationMigrationLockTimeout = (source) => {
  const matches = [...source.matchAll(/^\s*set local lock_timeout = '([1-9][0-9]*)s';\s*$/gm)];
  assert.equal(matches.length, 1, "0011 debe contener un único lock_timeout local de instalación");
  const milliseconds = Number(matches[0][1]) * 1000;
  assert.equal(milliseconds, 5000, "El presupuesto inmutable de instalación debe ser exactamente 5000 ms");
  return milliseconds;
};

const parseInstallationMigrationStatementTimeout = (source) => {
  const matches = [...source.matchAll(/^\s*set local statement_timeout = '([1-9][0-9]*)s';\s*$/gm)];
  assert.equal(matches.length, 1, "0011 debe contener un único statement_timeout local de instalación");
  const milliseconds = Number(matches[0][1]) * 1000;
  assert.equal(milliseconds, 120000, "El timeout SQL inmutable de instalación debe ser exactamente 120000 ms");
  return milliseconds;
};

const validateScenarioMap = (block) => {
  const ids = [...block.matchAll(/Id\s*=\s*"(MS\d{2}_[A-Z0-9_]+)"/g)].map((match) => match[1]);
  assert.equal(ids.length, 24, "La matriz debe declarar exactamente 24 escenarios");
  assert.equal(new Set(ids).size, 24, "La matriz contiene escenarios duplicados");
  for (let ordinal = 1; ordinal <= 24; ordinal += 1) {
    assert.equal(ids.filter((id) => id.startsWith(`MS${String(ordinal).padStart(2, "0")}_`)).length, 1);
  }
  return ids;
};

const validateWorkerSourceLifecycle = (source) => {
  const start = extractFunction(source, "Start-PsqlWorker");
  const wait = extractFunction(source, "Wait-PsqlWorker");
  const stop = extractFunction(source, "Stop-PsqlWorker");
  const remove = extractFunction(source, "Remove-DisposableWorkerSqlFile");
  const boundary = extractFunction(source, "Assert-DisposableWorkerSqlPath");
  const exact = `${extractFunction(source, "Invoke-ExactRepositorySqlFile")}\n${extractFunction(source, "Invoke-ExactRepositorySqlFileResult")}`;
  assert.match(start, /\[bool\]\$DeleteSqlFileOnCompletion = \$false/);
  assert.match(start, /\[AllowNull\(\)\]\[object\]\$DisposableSqlOwnershipState = \$null/);
  assert.doesNotMatch(wait, /Remove-Item\s+-LiteralPath\s+\$Worker\.SqlFile/);
  assert.doesNotMatch(stop, /Remove-Item\s+-LiteralPath\s+\$Worker\.SqlFile/);
  assert.match(wait, /Remove-DisposableWorkerSqlFile -Worker \$Worker/);
  assert.match(stop, /Remove-DisposableWorkerSqlFile -Worker \$Worker/);
  assert.match(start, /ExecutionContext/);
  assert.match(start, /Update-ExecuteWorkerManifest -ExecutionContext \$executionContext -ProcessId \$processId -Operation "add"/);
  requireInOrder(start, ['Operation "add"', 'Update-ExecuteWorkerManifest -ExecutionContext $executionContext', "$worker = [pscustomobject]", "return $worker"], "Todo worker debe quedar durable antes de retornar");
  requireInOrder(wait, ["Assert-Condition -Condition $Worker.Process.HasExited", 'Operation "remove"', "Update-ExecuteWorkerManifest -ExecutionContext $Worker.ExecutionContext"], "Wait debe retirar PID sólo después del fin real");
  requireInOrder(stop, ["Invoke-PsqlWorkerStartFailureCleanup", "$cleanup.Succeeded", "Remove-DisposableWorkerSqlFile", "Complete-PsqlDisposableWorkerOwnership", "return $cleanup"], "Stop debe conservar el resultado estructurado y completar sólo tras cleanup exitoso");
  requireInOrder(remove, ["DeleteSqlFileOnCompletion -ne $true", "DisposableSqlOwnershipState", 'OwnerState -ceq "worker"', "ProcessTerminationObserved = $true", "Assert-PsqlDisposableFrozenIdentity", "Remove-Item -LiteralPath $ownershipState.CanonicalPath"], "La eliminación debe estar cercada por owner, salida e identidad");
  assert.match(boundary, /\[string\]::Equals\(\$canonicalParent, \$canonicalRunDirectory, \[System\.StringComparison\]::OrdinalIgnoreCase\)/);
  assert.match(boundary, /\$canonicalFileName -cmatch '\^worker_\[a-z0-9_\]\+_\[0-9a-f\]\{32\}\\\.sql\$'/);
  assert.match(boundary, /-not \$canonicalFileName\.Contains\(':'\)/);
  assert.match(boundary, /-not \(\$full \+ \[System\.IO\.Path\]::DirectorySeparatorChar\)\.StartsWith\(\$repositoryRoot/);
  assert.match(boundary, /FileAttributes\]::ReparsePoint/);
  assert.match(boundary, /-not \$item\.PSIsContainer/);
  assert.match(boundary, /MigrationPath, \$script:PreflightPath, \$script:VerifierPath, \$script:RollbackPath/);
  assert.doesNotMatch(boundary, /manifest\.local\.json|final-postcheck\.local\.txt|multisession-evidence\.local\.txt\.publishing|worker_fixture\.sql|WORKER_fixture_/);
  assert.equal(occurrences(exact, /-DeleteSqlFileOnCompletion \$false/g), 2);
  const synchronize = extractFunction(source, "Update-ExecuteWorkerManifest");
  assert.match(synchronize, /Assert-WorkerPidSetsAgree/);
  assert.match(synchronize, /Write-Manifest/);
  const pidFixtures = extractFunction(source, "Assert-WorkerPidContractFixtures");
  assert.match(pidFixtures, /101, 202/);
  assert.match(pidFixtures, /ManifestPids @\(202\) -PidFilePids @\(202\)/);
  assert.match(pidFixtures, /manifest_active_worker_pid_duplicate_rejected/);
  assert.match(pidFixtures, /worker_pid_sources_disagree/);
  for (const helper of ["Invoke-Phase02InstallationMatrix", "Invoke-AdvisoryWaitPair", "Invoke-WallClockScenarios", "Invoke-AuthorityLossScenario"]) {
    assert.match(extractFunction(source, helper), /Start-PsqlWorker/, `${helper} debe usar el tracker central`);
  }
  assert.match(extractFunction(source, "Invoke-Phase03RollbackMatrix"), /Start-StagedRollbackRelationHolder/, "PHASE_03 debe usar el holder staged rastreado");
  const disposableStartLines = source.split("\n").filter((line) => line.includes("Start-PsqlWorker") && line.includes("-DeleteSqlFileOnCompletion $true"));
  assert.ok(disposableStartLines.length >= 4, "Deben conservarse los callers transitorios directos además del holder staged de PHASE_03");
  for (const line of disposableStartLines) assert.ok(line.includes("-DisposableSqlOwnershipState"), "Todo Start-PsqlWorker desechable requiere ownership state visible al caller");
  const stagedRuntime = extractFunction(source, "Start-StagedRuntimeAdvisoryHolder");
  assert.match(stagedRuntime, /\[Parameter\(Mandatory = \$true\)\]\[object\]\$DisposableSqlOwnershipState/);
  requireInOrder(stagedRuntime, ["$process.Start()", "$processStartState.Process = $process", "$processStartState.ProcessStarted = $true", "$DisposableSqlOwnershipState.Process = $process", '$DisposableSqlOwnershipState.OwnerState = "starter"', "Get-PsqlProcessId", "Clear-PsqlStartInfoMaterial", "ReadLineAsync", "Set-PsqlDisposableWorkerOwnership", "return $worker"], "El holder staged transitorio debe usar escrow inmediato antes de trabajo falible");
};

const validatePsqlProcessTimeoutContract = (source) => {
  const resolve = extractFunction(source, "Resolve-PsqlProcessTimeoutMilliseconds");
  const file = extractFunction(source, "Invoke-PsqlFile");
  const sql = extractFunction(source, "Invoke-PsqlSql");
  const start = extractFunction(source, "Start-PsqlWorker");
  const createSql = extractFunction(source, "New-SqlFile");
  const verifiedArtifact = extractFunction(source, "New-PsqlVerifiedTransientArtifact");
  const freezeIdentity = extractFunction(source, "Set-PsqlDisposableFrozenIdentity");
  const newOwnership = extractFunction(source, "New-PsqlDisposableOwnershipState");
  const callerOwnership = extractFunction(source, "Set-PsqlDisposableCallerOwnership");
  const controllerOwnership = extractFunction(source, "Set-PsqlDisposableControllerOwnership");
  const starterOwnership = extractFunction(source, "Set-PsqlDisposableStarterOwnership");
  const workerOwnership = extractFunction(source, "Set-PsqlDisposableWorkerOwnership");
  const workerCollection = extractFunction(source, "Complete-PsqlDisposableWorkerOwnership");
  const ownershipInvariant = extractFunction(source, "Assert-PsqlDisposableOwnershipInvariant");
  const stateIdentity = extractFunction(source, "Assert-PsqlDisposableStateIdentity");
  const frozenIdentity = extractFunction(source, "Assert-PsqlDisposableFrozenIdentity");
  const controllerCleanup = extractFunction(source, "Invoke-PsqlDisposableControllerCleanup");
  const ownershipCleanup = extractFunction(source, "Invoke-PsqlDisposableOwnershipCleanup");
  const startCleanup = extractFunction(source, "Invoke-PsqlWorkerStartFailureCleanup");
  const outerCleanup = extractFunction(source, "Invoke-PsqlSqlOuterHandoffCleanup");
  const exact = `${extractFunction(source, "Invoke-ExactRepositorySqlFile")}\n${extractFunction(source, "Invoke-ExactRepositorySqlFileResult")}`;
  const fileParams = extractParamBlock(file, "Invoke-PsqlFile");
  const sqlParams = extractParamBlock(sql, "Invoke-PsqlSql");
  const startParams = extractParamBlock(start, "Start-PsqlWorker");

  assert.match(extractParamBlock(createSql, "New-SqlFile"), /\[ValidateSet\("caller", "controller"\)\]\[string\]\$InitialOwner/);
  assert.doesNotMatch(createSql, /return \$creationState\.Path/, "New-SqlFile no puede perder la identidad verificada");
  requireInOrder(createSql, ["ExpectedSha256 = Get-TextSha256", "ExpectedByteLength =", "Assert-TransientSqlFileVerified", "New-PsqlVerifiedTransientArtifact", "return $artifact"], "New-SqlFile debe retornar el artefacto verificado completo");
  const artifactReturn = verifiedArtifact.slice(verifiedArtifact.indexOf("return [pscustomobject]@{"));
  for (const property of ["Path", "CanonicalPath", "CanonicalRunDirectory", "CanonicalFileName", "ExpectedSha256", "ExpectedByteLength", "OwnershipState"]) assert.match(artifactReturn, new RegExp(`^\\s+${property}\\s*=`, "m"), `Falta propiedad de artefacto: ${property}`);
  requireInOrder(verifiedArtifact, ["CreationState.Verified", "New-PsqlDisposableOwnershipState", "ExpectedSha256 = [string]$CreationState.ExpectedSha256", "ExpectedByteLength = [long]$CreationState.ExpectedByteLength", "Set-PsqlDisposableFrozenIdentity", "$state.OwnerState = $InitialOwner", "Assert-PsqlDisposableOwnershipInvariant", "return [pscustomobject]"], "El artefacto debe transferir directamente la identidad verificada");
  assert.doesNotMatch(verifiedArtifact, /Get-PsqlDisposableIdentity|Get-Sha256/, "El artefacto inicial no puede rehashar el pathname");
  requireInOrder(freezeIdentity, ['OwnerState -ceq "none"', "-not $State.IdentityFrozen", "$State.FrozenCanonicalPath", "$State.FrozenExpectedSha256", "$State.FrozenExpectedByteLength", "$State.IdentityFrozen = $true"], "La identidad sólo puede congelarse una vez");

  const canonicalParameter = /\[ValidateRange\(0, 600000\)\]\[int\]\$ProcessTimeoutMilliseconds = 0/;
  assert.match(fileParams, canonicalParameter, "Invoke-PsqlFile debe declarar el timeout de proceso canónico");
  assert.match(sqlParams, canonicalParameter, "Invoke-PsqlSql debe declarar el timeout de proceso canónico");
  assert.equal(occurrences(fileParams, /\$ProcessTimeoutMilliseconds\b/g), 1, "Invoke-PsqlFile debe declarar exactamente un parámetro de timeout");
  assert.equal(occurrences(sqlParams, /\$ProcessTimeoutMilliseconds\b/g), 1, "Invoke-PsqlSql debe declarar exactamente un parámetro de timeout");
  assert.doesNotMatch(startParams, /\$ProcessTimeoutMilliseconds\b/, "Start-PsqlWorker no es owner del timeout de terminación");
  assert.doesNotMatch(start, /\$ProcessTimeoutMilliseconds\b/, "Start-PsqlWorker no debe conservar un timeout sin uso");
  assert.equal(occurrences(file, /\$ProcessTimeoutMilliseconds\b/g), 2, "Invoke-PsqlFile no puede depender de una variable libre de timeout");
  assert.equal(occurrences(sql, /\$ProcessTimeoutMilliseconds\b/g), 2, "Invoke-PsqlSql debe declarar y reenviar exactamente el timeout");
  assert.match(sql, /Invoke-PsqlFile[^\n]*-ProcessTimeoutMilliseconds \$ProcessTimeoutMilliseconds/);
  assert.match(fileParams, /\[AllowNull\(\)\]\[object\]\$DisposableSqlOwnershipState = \$null/);
  assert.match(sql, /-DisposableSqlOwnershipState \$artifact\.OwnershipState/);
  assertNamedArgumentsDeclared(sql, "Invoke-PsqlFile", fileParams);
  assertNamedArgumentsDeclared(exact, "Invoke-PsqlFile", fileParams);

  const resolveParams = extractParamBlock(resolve, "Resolve-PsqlProcessTimeoutMilliseconds");
  assert.match(resolveParams, /\[long\]\$StatementTimeoutMilliseconds/);
  assert.match(resolveParams, /\[long\]\$ProcessTimeoutMilliseconds/);
  for (const marker of ["psql_process_timeout_negative_rejected", "psql_process_timeout_range_rejected", "psql_process_timeout_overflow_rejected", "psql_process_timeout_resolution_rejected", "$StatementTimeoutMilliseconds + 30000", "return [int]$resolved"]) assert.ok(resolve.includes(marker), `Falta contrato de resolución: ${marker}`);
  assert.match(resolve, /if \(\$ProcessTimeoutMilliseconds -gt 0\)[\s\S]*return \[int\]\$ProcessTimeoutMilliseconds/);

  for (const marker of ["FrozenCanonicalPath = $canonicalPath", "FrozenCanonicalRunDirectory = $canonicalRunDirectory", "FrozenCanonicalFileName =", "FrozenExpectedSha256 = $null", "FrozenExpectedByteLength = $null", "IdentityFrozen = $false", 'OwnerState = "none"', "ProcessStartObserved = $false", "ProcessTerminationObserved = $false", "Process = $null", "ProcessId = $null", "ProcessIdObserved = $false", "Worker = $null", "StartInfoMaterialClearAttempted = $false", "StartInfoMaterialCleared = $false", "CleanupAttempted = $false", "CleanupCompleted = $false", "AbsenceObserved = $false", "SecondaryCleanupErrors = @()", "PrimaryErrorRecord = $null", "PrimaryFailureClass = $null", "PrimaryScenario = $null"]) {
    assert.ok(newOwnership.includes(marker), `Falta estado de ownership: ${marker}`);
  }
  for (const property of ["CallerOwns", "ControllerOwns", "StarterOwns", "WorkerOwns", "CanonicalPath", "CanonicalRunDirectory", "CanonicalFileName", "ExpectedSha256", "ExpectedByteLength"]) assert.match(newOwnership, new RegExp(`ScriptProperty -Name ${property}`));
  assert.match(ownershipInvariant, /OwnerState -cin @\("none", "caller", "controller", "starter", "worker", "completed"\)/);
  assert.match(ownershipInvariant, /psql_disposable_multiple_owners_rejected/);
  for (const marker of ["psql_disposable_none_state_rejected", "psql_disposable_prestart_state_rejected", "psql_disposable_starter_state_rejected", "psql_disposable_worker_state_rejected", "psql_disposable_completed_invariant_rejected", "ProcessIdObserved", "ReferenceEquals", "StartInfoMaterialCleared", "ProcessTerminationObserved", "AbsenceObserved", "Test-PsqlStartInfoContainsPgMaterial"]) assert.ok(ownershipInvariant.includes(marker), `Falta contrato completo de invariant: ${marker}`);
  requireInOrder(callerOwnership, ["Assert-PsqlDisposableOwnershipInvariant", 'OwnerState -ceq "none"', "Get-PsqlDisposableIdentity", "Assert-PsqlDisposableStateIdentity", '$State.OwnerState = "caller"'], "El caller debe revalidar sin reescribir identidad");
  assert.doesNotMatch(callerOwnership, /Set-PsqlDisposableFrozenIdentity/, "Caller no puede volver a congelar identidad");
  assert.doesNotMatch(callerOwnership, /\$State\.Frozen(?:Canonical|Expected)/, "Caller no puede reescribir campos congelados");
  assert.equal(occurrences(callerOwnership, /\$State\.OwnerState = "caller"/g), 1, "Caller adquiere ownership exactamente una vez después de validar");
  requireInOrder(controllerOwnership, ["Assert-PsqlDisposableOwnershipInvariant", "$previousOwner", 'previousOwner -cin @("none", "caller")', "Get-PsqlDisposableIdentity", "Assert-PsqlDisposableStateIdentity", '$State.OwnerState = "controller"'], "El controller debe revalidar antes de mutar");
  assert.doesNotMatch(controllerOwnership, /Set-PsqlDisposableFrozenIdentity/, "Controller no puede volver a congelar identidad");
  assert.doesNotMatch(controllerOwnership, /\$State\.Frozen(?:Canonical|Expected)/, "Controller no puede reescribir campos congelados");
  assert.equal(occurrences(controllerOwnership, /\$State\.OwnerState = "controller"/g), 1, "Controller adquiere ownership exactamente una vez después de validar");
  requireInOrder(starterOwnership, ["$previous = [pscustomobject]", "$State.Process = $Process", "$State.ProcessStartObserved = $true", "$State.ProcessId = $null", "$State.ProcessIdObserved = $false", '$State.OwnerState = "starter"', 'previous.OwnerState -ceq "controller"', "Assert-PsqlDisposableOwnershipInvariant", "catch {", "$State.Process = $previous.Process", "$State.OwnerState = $previous.OwnerState"], "El helper starter debe capturar y revertir de forma atómica si rechaza");
  assert.doesNotMatch(starterOwnership, /Get-PsqlDisposableIdentity|Get-PsqlProcessId|\.Id\b/, "Starter no puede consultar identidad ni PID durante el escrow");
  assert.doesNotMatch(starterOwnership, /\$State\.Frozen(?:Canonical|Expected)/, "Starter no puede reescribir campos congelados");
  assert.equal(occurrences(starterOwnership, /\$State\.OwnerState = "starter"/g), 1, "Starter adquiere ownership exactamente una vez después de validar");
  assert.doesNotMatch(starterOwnership, /\$State\.OwnerState = "controller"/, "Starter no puede conservar ownership controller simultáneo");
  assert.match(stateIdentity, /\[string\]\$State\.ExpectedSha256 -ceq \[string\]\$Identity\.ExpectedSha256/);
  assert.match(stateIdentity, /\[long\]\$State\.ExpectedByteLength -eq \[long\]\$Identity\.ExpectedByteLength/);
  assert.doesNotMatch(stateIdentity, /\$State\.(?:FrozenExpectedSha256|FrozenExpectedByteLength)\s*=/, "La revalidación no puede adoptar la identidad observada");
  requireInOrder(workerOwnership, [
    "Assert-PsqlDisposableOwnershipInvariant", "Assert-PsqlDisposableFrozenIdentity", 'OwnerState -ceq "starter"',
    "ProcessStartObserved", "ProcessIdObserved", "ReferenceEquals($State, $Worker.DisposableSqlOwnershipState)",
    "CanonicalRunDirectory", "Test-PsqlStartInfoContainsPgMaterial", "LocalPidRecorded", "ExecutePidRecorded",
    "CleanupInvocationCount -eq 0", "WorkerTransferCount -eq 0", "$previousWorker = $State.Worker",
    "$previousOwnerState", "$previousWorkerTransferCount", "try {", "$State.Worker = $Worker",
    '$State.OwnerState = "worker"', "$State.WorkerTransferCount = $previousWorkerTransferCount + 1",
    "Assert-PsqlDisposableOwnershipInvariant", "catch {", "$transitionError = $_",
    "$State.Worker = $previousWorker", "$State.OwnerState = $previousOwnerState",
    "$State.WorkerTransferCount = $previousWorkerTransferCount", "throw $transitionError",
  ], "El worker debe validarse por completo y revertir property-for-property si el handoff falla");
  assert.equal(occurrences(workerOwnership, /\$State\.OwnerState = "worker"/g), 1, "El setter sólo puede aplicar worker una vez");
  assert.doesNotMatch(workerOwnership, /OwnerState = "worker"[\s\S]*OwnerState = "controller"/);
  requireInOrder(workerCollection, ['OwnerState -ceq "worker"', "ProcessTerminationObserved", "Assert-PsqlDisposableFrozenIdentity", "-not (Test-Path -LiteralPath $State.CanonicalPath)", '$State.OwnerState = "completed"', "$State.CleanupCompleted = $true", "$State.AbsenceObserved = $true"], "La colección debe terminar ownership sólo tras salida y ausencia");
  requireInOrder(frozenIdentity, ["Get-PsqlDisposableIdentity", "CanonicalPath", "CanonicalRunDirectory", "CanonicalFileName", "ExpectedSha256", "Get-Sha256", "psql_disposable_identity_hash_mismatch"], "La eliminación debe comparar la identidad y hash congelados");
  requireInOrder(ownershipCleanup, ["Assert-PsqlDisposableOwnershipInvariant", "RequiredOwner", "$State.CleanupAttempted = $true", "PSQL_DISPOSABLE_PATH_GUARD", "Assert-PsqlDisposableFrozenIdentity", "PSQL_DISPOSABLE_PATH_REMOVE", "Remove-Item -LiteralPath $State.CanonicalPath", "PSQL_DISPOSABLE_PATH_ABSENT", "-not (Test-Path -LiteralPath $State.CanonicalPath)", "$State.SecondaryCleanupErrors", '$State.OwnerState = "completed"', "$State.CleanupCompleted = $true"], "El cleanup debe estar ligado a ownership activo e identidad congelada");
  assert.match(controllerCleanup, /OwnerState -cin @\("caller", "controller"\)/);
  assert.match(ownershipCleanup, /Name = "PSQL_DISPOSABLE_PATH_ABSENT"[\s\S]*psql_disposable_cleanup_absence_rejected/);

  requireInOrder(file, [
    "$worker = $null",
    "$workerCollected = $false",
    "$ownershipState =",
    "New-PsqlDisposableOwnershipState -SqlFile $SqlFile -RunDirectory $RunDirectory",
    "try {",
    "Assert-DisposableWorkerSqlPath",
    'OwnerState -ceq "caller"',
    "Set-PsqlDisposableControllerOwnership -State $ownershipState",
    "Assert-PsqlDisposableFrozenIdentity -State $ownershipState",
    "Test-Path -LiteralPath $SqlFile -PathType Leaf",
    "$effectiveProcessTimeout = Resolve-PsqlProcessTimeoutMilliseconds",
    "$worker = Start-PsqlWorker",
    "-DisposableSqlOwnershipState $ownershipState",
    "$result = Wait-PsqlWorker -Worker $worker -TimeoutMilliseconds $effectiveProcessTimeout",
    "$workerCollected = $true",
    "catch {",
    "$primaryError = $_",
    "$primaryFailureClass =",
    "$primaryScenario =",
    "Stop-PsqlWorker -Worker $worker",
    'OwnerState -ceq "worker"',
    'Name = "PSQL_FILE_WORKER_HANDOFF_STATE"',
    "psql_file_worker_handoff_state_rejected",
    "Stop-PsqlWorker -Worker $ownershipState.Worker",
    "Invoke-PsqlDisposableControllerCleanup -State $ownershipState",
    "Complete-OrchestrationCleanup -PrimaryError $primaryError",
  ], "Invoke-PsqlFile debe adquirir ownership, validar, resolver, iniciar, transferir, recolectar y limpiar en orden");
  assert.doesNotMatch(file, /sqlLifecycleValidated/, "La eliminación no puede depender de validación completada");
  assert.doesNotMatch(file, /Wait-PsqlWorker[^\n]*-TimeoutMilliseconds \$(?:Statement|Lock)TimeoutMilliseconds/);
  assert.match(file, /Invoke-OrchestrationCleanup -EmitFailureMarkers[\s\S]*Stop-PsqlWorker -Worker \$worker/);
  assert.match(file, /\$null -eq \$worker -and \$DeleteSqlFileOnCompletion -and[\s\S]*OwnerState -ceq "worker"[\s\S]*psql_file_worker_handoff_state_rejected/);
  assert.match(file, /\$null -eq \$worker -and \$DeleteSqlFileOnCompletion -and[\s\S]*OwnerState -cin @\("caller", "controller"\)/);
  assert.match(file, /Complete-OrchestrationCleanup -PrimaryError \$primaryError -PrimaryScenario \$primaryScenario/);
  assert.match(file, /else \{\s*\$cleanup = \[pscustomobject\]@\{ Succeeded = \$true; SecondaryErrors = @\(\) \}\s*\}/);
  assert.doesNotMatch(file, /throw \$primaryError/);
  assert.match(source, /\$script:RepositorySqlProcessTimeoutMilliseconds = 210000/);
  assert.equal(occurrences(exact, /-ProcessTimeoutMilliseconds \$script:RepositorySqlProcessTimeoutMilliseconds/g), 2, "Los wrappers protegidos requieren timeout determinista");
  assert.equal(occurrences(exact, /-DeleteSqlFileOnCompletion \$false/g), 2, "Los SQL protegidos nunca son desechables");
  assert.doesNotMatch(extractFunction(source, "New-PsqlStartInfo"), /ProcessTimeoutMilliseconds/);

  requireInOrder(sql, [
    "$handoffState = $null",
    "try {",
    "$artifact = New-SqlFile",
    "-InitialOwner caller",
    "$handoffState = $artifact.OwnershipState",
    "Invoke-PsqlFile",
    "-DisposableSqlOwnershipState $artifact.OwnershipState",
    "catch {",
    "$handoffError = $_",
    "$handoffCleanup = Invoke-OrchestrationCleanup",
    'Name = "PSQL_HANDOFF_OUTER_CLEANUP"',
    "Invoke-PsqlSqlOuterHandoffCleanup -State $handoffState",
    "Complete-OrchestrationCleanup -PrimaryError $handoffError",
  ], "Invoke-PsqlSql debe proteger el handoff completo e idempotente");
  assert.match(outerCleanup, /OwnerState -cin @\("caller", "controller"\)/);
  assert.match(outerCleanup, /OwnerState -ceq "completed"/);
  assert.match(outerCleanup, /psql_handoff_completed_path_reappeared/);
  assert.doesNotMatch(outerCleanup, /OwnerState -ceq "completed"[\s\S]*Remove-Item/);
  assert.doesNotMatch(sql, /return \$creationState\.Path|New-PsqlDisposableOwnershipState[\s\S]*New-SqlFile/);

  requireInOrder(start, ["Assert-PsqlDisposableStarterPreconditions", "$startInfo = New-PsqlStartInfo", "$startState.StartInfo = $startInfo", "$process.StartInfo = $startInfo", "$processStarted = $false", "$fallbackProcess = $process", "$fallbackStartInfo = $startInfo", "try {", "$process.Start()", "$processStarted = $true", "$startState.Process = $process", "$startState.ProcessStartObserved = $true", '$startState.OwnerState = "starter"', "$processId = Get-PsqlProcessId -Process $process", "$startState.ProcessId = $processId", "$startState.ProcessIdObserved = $true", "Clear-PsqlStartInfoMaterial", "ReadToEndAsync", "LocalPidAddAttempted = $true", 'Operation "add"', "ExecutePidAddAttempted = $true", "Update-ExecuteWorkerManifest", "$worker = [pscustomobject]", "ProcessStartState = $startState", "Test-PsqlStartInfoContainsPgMaterial", "worker_pid_registration_incomplete", "Assert-PsqlDisposableFrozenIdentity", "worker_candidate_incomplete", "Set-PsqlDisposableWorkerOwnership", "return $worker", "catch {", "$workerStartError = $_", "$startCleanup = Invoke-PsqlWorkerStartFailureCleanup", "-FallbackProcess $fallbackProcess", "Complete-OrchestrationCleanup"], "Start-PsqlWorker debe terminar todo trabajo falible antes del handoff worker");
  const processStartIndex = start.indexOf("$process.Start()");
  const processEscrowIndex = start.indexOf("$startState.Process = $process", processStartIndex);
  assert.ok(processStartIndex >= 0 && processEscrowIndex > processStartIndex, "Start-PsqlWorker debe capturar el proceso tras Start");
  assert.doesNotMatch(start.slice(processStartIndex + "$process.Start()".length, processEscrowIndex), /Assert-|Get-PsqlProcessId|ReadToEndAsync|Clear-PsqlStartInfoMaterial|Update-(?:WorkerPidManifest|ExecuteWorkerManifest)/, "Nada falible puede preceder el escrow inmediato");
  assert.match(start, /\$startState\.StartInfo = \$startInfo[\s\S]*?\$process\.Start\(\)/, "StartInfo debe almacenarse antes de Process.Start");
  assert.match(start, /Clear-PsqlStartInfoMaterial[\s\S]*?ReadToEndAsync/, "StartInfo debe sanitizarse antes de iniciar lectores");
  assert.match(start, /Test-PsqlStartInfoContainsPgMaterial[\s\S]*?Set-PsqlDisposableWorkerOwnership[\s\S]*?return \$worker/, "No puede transferir o retornar un worker con material PostgreSQL");
  const genericTransferNeedle = "Set-PsqlDisposableWorkerOwnership -State $startState -Worker $worker";
  const genericTransferIndex = start.indexOf(genericTransferNeedle);
  const genericReturnIndex = start.indexOf("return $worker", genericTransferIndex);
  assert.ok(genericTransferIndex >= 0 && genericReturnIndex > genericTransferIndex, "Falta el handoff terminal genérico");
  assert.equal(start.slice(genericTransferIndex + genericTransferNeedle.length, genericReturnIndex).trim(), "", "Nada ejecutable puede seguir al handoff worker antes del return");
  requireInOrder(startCleanup, ["PSQL_START_WORKER_OWNERSHIP_INTEGRITY", "complete_worker", "invalid_partial_worker", "PSQL_START_INFO_CLEAR", "PSQL_START_FALLBACK_ESCROW", "PSQL_START_INPUT_CLOSE", "PSQL_START_PROCESS_TERMINATE", "ProcessTerminationObserved = $true", "PSQL_START_LOCAL_PID_REMOVE", "ProcessTerminationObserved", "PSQL_START_EXECUTE_PID_REMOVE", "ProcessTerminationObserved", "PSQL_START_DISPOSABLE_SQL_REMOVE", "Invoke-PsqlDisposableStarterCleanup", "Remove-DisposableWorkerSqlFile -Worker $State.Worker", "Complete-PsqlDisposableWorkerOwnership -State $State", "worker_owned_start_state_incomplete", "$State.SecondaryCleanupErrors", "return $cleanup"], "El cleanup post-start debe clasificar worker, sanitizar y observar terminación antes de PID y SQL");
  assert.ok(occurrences(startCleanup, /\$State\.ProcessTerminationObserved -and \$cleanupProcess\.HasExited/g) >= 3, "PID y SQL requieren terminación observada");
  assert.doesNotMatch(startCleanup, /StandardInput\.Close\(\)\s*\}\s*catch\s*\{\s*\}/, "El cierre de stdin no puede silenciar su fallo secundario");
  assert.equal(occurrences(start, /\$startState\.LocalPidAddAttempted = \$true/g), 1, "El alta PID local debe ocurrir una vez después del escrow");
  assert.equal(occurrences(start, /\$startState\.ExecutePidAddAttempted = \$true/g), 1, "El alta PID Execute debe ocurrir una vez después del escrow");
  assert.doesNotMatch(start, /Invoke-SecondaryFailureOperation[\s\S]*Stop-PsqlWorker[\s\S]*throw \$workerStartError/);

  const timeoutFixtures = extractFunction(source, "Assert-PsqlProcessTimeoutContractFixtures");
  for (const marker of ["5000) -eq 5000", "180000) -eq 180000", "90000 -ProcessTimeoutMilliseconds 0) -eq 120000", "180000 -ProcessTimeoutMilliseconds 0) -eq 210000", "Get-Command Invoke-PsqlFile", "Get-Command Invoke-PsqlSql", "Get-Command Start-PsqlWorker", "psql_process_timeout_overflow_rejected", "Assert-PsqlTimeoutBindingDescriptor"]) assert.ok(timeoutFixtures.includes(marker), `Falta fixture de timeout: ${marker}`);
  const ownership = extractFunction(source, "Invoke-PsqlWorkerOwnershipFixture");
  requireInOrder(ownership, ["$worker = $null", "$workerCollected = $false", "try {", "$worker = & $StartOperation", "$result = & $WaitOperation $worker", "$workerCollected = $true", "catch {", "$primaryError = $_", "Invoke-SecondaryFailureOperation", "& $StopOperation $worker", "throw $primaryError"], "El fixture de ownership debe preservar el fallo primario");
  const ownershipFixtures = extractFunction(source, "Assert-PsqlWorkerOwnershipFixtures");
  for (const marker of ["$startCount -eq 0", "$cleanupState.Count -eq 1", "process_terminated|pid_removal_attempted", "fixture_primary_preserved", "$normalStopState.Count -eq 0", "worker_sql_delete_repository_rejected", "Assert-DisposableWorkerSqlPath"]) assert.ok(ownershipFixtures.includes(marker), `Falta fixture de ownership: ${marker}`);

  const db23 = extractFunction(source, "Assert-Db23PsqlHandoffFixtures");
  for (const marker of [
    "validate-db23-", "New-SqlFile", "Invoke-PsqlFile", "Invoke-PsqlSql",
    "StatementTimeoutMilliseconds 570001", "StatementTimeoutMilliseconds -1",
    "psql_process_timeout_overflow_rejected", "psql_statement_timeout_negative_rejected",
    "worker_sql_file_missing", "worker_sql_delete_repository_rejected",
    "$directState.CleanupInvocationCount -eq 1", "$directState.RemovalAttemptCount -eq 1",
    "$handoffState.CleanupInvocationCount -eq 1", "$protectedState.CleanupAttempted",
    "Get-Sha256 -Path $script:MigrationPath", "$script:PsqlHandoffFixtureFault = \"removal_failure\"",
    "SecondaryCleanupErrors", "-InitialOwner caller", "Set-PsqlDisposableControllerOwnership",
    "Set-PsqlDisposableWorkerOwnership", "Complete-PsqlDisposableWorkerOwnership",
    "Get-TransientWorkerSqlFileCount -RunDirectory $fixtureRoot", "$script:Db23FixtureStartAttemptCount -eq 0",
  ]) assert.ok(db23.includes(marker), `Falta fixture física DB-23: ${marker}`);
  assert.doesNotMatch(db23, /Read-Host|Process\.Start|\.Start\(\)|pg_dump/i, "Las fixtures DB-23 no pueden iniciar procesos ni pedir credenciales");
  const db24 = extractFunction(source, "Assert-Db24TransientSqlIdentityAndStarterEscrowFixtures");
  for (const marker of [
    "validate-db24-", "manifest.local.json", "worker-pids.local.json", "final-postcheck.local.txt",
    "failure-postcheck.local.txt", "multisession-evidence.local.txt", "multisession-failure.local.txt",
    "multisession-evidence.local.txt.publishing", "raw_fixture.stdout.local.txt", "worker_fixture.sql",
    "WORKER_fixture_", ".sql.extra", 'Join-Path $fixtureRoot "nested"', "Get-Sha256",
    "psql_disposable_handoff_identity_rejected", "$beforeHandoff -ceq $afterHandoff",
    "$completedState.CleanupInvocationCount -eq 1", "Invoke-PsqlSqlOuterHandoffCleanup",
    "psql_handoff_completed_path_reappeared", "psql_disposable_identity_hash_mismatch",
    "New-Db24SyntheticProcess", 'OwnerState -ceq "starter"', 'OwnerState -ceq "worker"',
    'OwnerState -ceq "completed"', "Invoke-PsqlWorkerStartFailureCleanup", "FixtureLocalPidRemovalCount",
    "FixtureExecutePidRemovalCount", "ProcessTerminationObserved", "db24_paired_partial_start_fixture_rejected",
    "Get-Sha256 -Path $script:MigrationPath", "$script:Db24FixtureStartAttemptCount -eq 0",
  ]) assert.ok(db24.includes(marker), `Falta fixture física DB-24: ${marker}`);
  assert.ok(occurrences(db24, /\[System\.IO\.File\]::WriteAllText/g) >= 5, "DB-24 debe crear archivos físicos no-worker y reemplazos");
  assert.doesNotMatch(db24, /Read-Host|Process\.Start|\.Start\(\)|pg_dump/i, "Las fixtures DB-24 no pueden iniciar procesos ni pedir credenciales");
  const pairedCleanup = extractFunction(source, "Remove-UnownedTransientSqlFile");
  assert.match(pairedCleanup, /OwnerState -cin @\("starter", "worker"\)/);
  assert.match(pairedCleanup, /OwnerState -cin @\("caller", "controller"\)/);
  assert.match(extractFunction(source, "Invoke-Phase00Validate"), /Assert-Db22TransientSqlCreationFixtures[\s\S]*Assert-Db23PsqlHandoffFixtures[\s\S]*Assert-Db24TransientSqlIdentityAndStarterEscrowFixtures/);

  const probe = extractFunction(source, "Invoke-AdvisoryPairObservationProbe");
  assert.match(probe, /ProcessTimeoutMilliseconds \$script:ObserverProbeProcessTimeoutMilliseconds/);
};

const validateDb25VerifiedIdentityAndEscrowContract = (source) => {
  const fixture = extractFunction(source, "Assert-Db25VerifiedArtifactAndProcessEscrowFixtures");
  const phase00 = extractFunction(source, "Invoke-Phase00Validate");
  const start = extractFunction(source, "Start-PsqlWorker");
  const stagedRuntime = extractFunction(source, "Start-StagedRuntimeAdvisoryHolder");
  const invariant = extractFunction(source, "Assert-PsqlDisposableOwnershipInvariant");
  const outerSql = extractFunction(source, "Invoke-PsqlSql");

  requireInOrder(phase00, ["Assert-Db22TransientSqlCreationFixtures", "Assert-Db23PsqlHandoffFixtures", "Assert-Db24TransientSqlIdentityAndStarterEscrowFixtures", "Assert-Db25VerifiedArtifactAndProcessEscrowFixtures"], "DB-25 debe ejecutarse después de preservar DB-22–DB-24");
  for (const marker of [
    "validate-db25-", "db25_verified_caller", "db25_verified_controller", "ExpectedByteLength",
    'Name = "path"', 'Name = "directory"', 'Name = "filename"', 'Name = "hash"', 'Name = "length"',
    '"db25_failure_atomic_" + $mutation.Name + "_rejected"', "db25_double_freeze_failure_atomic_rejected",
    'Db25HandoffFault = "replace_before_invoke"', "db25_creation_to_caller_replacement_rejected",
    "db25_replacement_independent_finalizer_rejected", "db25_immediate_starter_escrow_rejected",
    "New-Db25SyntheticProcessWithFailingId", "Get-PsqlProcessId", "db25_process_id_primary_rejected",
    "db25_process_id_reference_termination_rejected", "db25_process_id_pid_cleanup_invented",
    "db25_start_info_normal_clear_rejected", "db25_start_info_failure_clear_rejected",
    "db25_start_info_secondary_primary_preservation_rejected", 'Db25HandoffFault = "recreate_completed"',
    "Invoke-PsqlSql", "db25_integrated_outer_cleanup_primary_preservation_rejected",
    "db25_staged_runtime_escrow_order_rejected", "psql_disposable_starter_state_rejected",
    "psql_disposable_worker_state_rejected", "psql_disposable_completed_invariant_rejected",
    "db25_protected_sql_contract_rejected", "db25_fixture_process_or_sql_residue_rejected",
    "db25_fixture_directory_residue_rejected", "$script:Db25FixtureStartAttemptCount -eq 0",
  ]) assert.ok(fixture.includes(marker), `Falta fixture DB-25: ${marker}`);
  assert.doesNotMatch(fixture, /^\s*(?:\[void\])?\$[A-Za-z][A-Za-z0-9_]*\.Start\(\)/m, "DB-25 no puede iniciar un proceso real");
  assert.match(fixture, /\bInvoke-PsqlSql\s+-Connection/, "La falla externa debe probarse por la ruta integrada");
  assert.match(fixture, /Invoke-PsqlSql\b[\s\S]*?Db25HandoffFault = "recreate_completed"|Db25HandoffFault = "recreate_completed"[\s\S]*?Invoke-PsqlSql\b/, "La falla externa debe probarse por la ruta integrada");
  assert.match(fixture, /protectedOwnerState\.OwnerState -ceq "none" -and -not \$protectedOwnerState\.IdentityFrozen/);

  const runtimeNewSqlLines = source.split("\n").filter((line) => /New-SqlFile\b/.test(line) && !/^\s*function New-SqlFile\b/.test(line) && !/\.IndexOf\(/.test(line));
  assert.ok(runtimeNewSqlLines.length >= 10, "Deben conservarse todos los callers runtime y fixtures del artefacto");
  for (const line of runtimeNewSqlLines) {
    assert.match(line, /\$[A-Za-z0-9_]*artifact[A-Za-z0-9_]*\s*=\s*New-SqlFile|\[void\]\(New-SqlFile/i, `New-SqlFile no puede asignarse a un pathname: ${line.trim()}`);
    assert.match(line, /-InitialOwner (?:caller|controller)/, `New-SqlFile requiere owner inicial explícito: ${line.trim()}`);
  }

  requireInOrder(stagedRuntime, ["$DisposableSqlOwnershipState.StartInfo = $startInfo", "$process.Start()", "$processStartState.Process = $process", "$processStartState.ProcessStarted = $true", "$DisposableSqlOwnershipState.Process = $process", "$DisposableSqlOwnershipState.ProcessStartObserved = $true", '$DisposableSqlOwnershipState.OwnerState = "starter"', "$processId = Get-PsqlProcessId", "Clear-PsqlStartInfoMaterial", "ReadLineAsync", "Update-WorkerPidManifest", "Set-PsqlDisposableWorkerOwnership", "return $worker"], "El holder runtime debe capturar ambos estados antes de PID, lectores y manifiestos");
  const stagedStartIndex = stagedRuntime.indexOf("$process.Start()");
  const stagedLocalEscrowIndex = stagedRuntime.indexOf("$processStartState.Process = $process", stagedStartIndex);
  assert.ok(stagedStartIndex >= 0 && stagedLocalEscrowIndex > stagedStartIndex);
  assert.doesNotMatch(stagedRuntime.slice(stagedStartIndex + "$process.Start()".length, stagedLocalEscrowIndex), /Assert-|Get-PsqlProcessId|ReadLineAsync|Clear-PsqlStartInfoMaterial|Update-(?:WorkerPidManifest|ExecuteWorkerManifest)/, "El holder runtime no puede ejecutar trabajo falible antes de su escrow local");
  assert.match(stagedRuntime.slice(stagedRuntime.indexOf("catch {")), /-FallbackProcess \$process -FallbackProcessStarted \$processStarted -FallbackStartInfo \$startInfo/);

  assert.match(invariant, /OwnerState -ceq "starter"[\s\S]*?ProcessStartObserved -and \$null -ne \$State\.Process/);
  assert.match(invariant, /OwnerState -ceq "worker"[\s\S]*?\$null -ne \$State\.Worker/);
  assert.match(invariant, /OwnerState -ceq "completed"[\s\S]*?-not \$State\.ProcessStartObserved -or \$State\.ProcessTerminationObserved/);
  assert.match(outerSql, /Invoke-OrchestrationCleanup -EmitFailureMarkers[\s\S]*?Invoke-PsqlSqlOuterHandoffCleanup/);
  assert.doesNotMatch(outerSql, /^\s*Invoke-PsqlSqlOuterHandoffCleanup -State \$handoffState\s*$/m, "El cleanup externo no puede escapar del boundary no-throwing");
  assert.match(start, /-FallbackProcess \$fallbackProcess -FallbackProcessStarted \$processStarted -FallbackStartInfo \$fallbackStartInfo/);
};

const validateDb26WorkerHandoffAndMarkerDeadlineContract = (source) => {
  const phase00 = extractFunction(source, "Invoke-Phase00Validate");
  const transfer = extractFunction(source, "Set-PsqlDisposableWorkerOwnership");
  const start = extractFunction(source, "Start-PsqlWorker");
  const startCleanup = extractFunction(source, "Invoke-PsqlWorkerStartFailureCleanup");
  const file = extractFunction(source, "Invoke-PsqlFile");
  const staged = extractFunction(source, "Start-StagedRuntimeAdvisoryHolder");
  const marker = extractFunction(source, "Wait-StagedRuntimeAdvisoryHolderMarker");
  const pair = extractFunction(source, "Invoke-AdvisoryWaitPair");
  const fixture = extractFunction(source, "Assert-Db26WorkerHandoffAndMarkerDeadlineFixtures");

  requireInOrder(phase00, ["Assert-Db25VerifiedArtifactAndProcessEscrowFixtures", "Assert-Db26WorkerHandoffAndMarkerDeadlineFixtures"], "DB-26 debe ejecutarse después de preservar DB-25");
  requireInOrder(transfer, [
    "Assert-PsqlDisposableOwnershipInvariant", "Assert-PsqlDisposableFrozenIdentity", 'OwnerState -ceq "starter"',
    "ProcessStartObserved", "ProcessIdObserved", "ReferenceEquals($State.Process, $Worker.Process)",
    "ReferenceEquals($State, $Worker.DisposableSqlOwnershipState)", "CanonicalPath", "CanonicalRunDirectory",
    "StartInfoMaterialCleared", "Test-PsqlStartInfoContainsPgMaterial", "LocalPidRecorded", "ExecutePidRecorded",
    "CleanupInvocationCount -eq 0", "WorkerTransferCount -eq 0", "$previousWorker = $State.Worker",
    "$previousOwnerState", "$previousWorkerTransferCount", "try {", "$State.Worker = $Worker",
    '$State.OwnerState = "worker"', "$State.WorkerTransferCount = $previousWorkerTransferCount + 1",
    "Assert-PsqlDisposableOwnershipInvariant", "catch {", "$transitionError = $_", "$State.Worker = $previousWorker",
    "$State.OwnerState = $previousOwnerState", "$State.WorkerTransferCount = $previousWorkerTransferCount", "throw $transitionError",
  ], "El handoff DB-26 debe validar antes de mutar y restaurar las tres propiedades en catch");
  assert.equal(occurrences(transfer, /\$State\.Worker = \$Worker/g), 1, "El handoff sólo puede poblar Worker una vez");
  assert.equal(occurrences(transfer, /\$State\.OwnerState = "worker"/g), 1, "El handoff sólo puede aplicar owner worker una vez");
  assert.equal(occurrences(transfer, /\$State\.WorkerTransferCount = \$previousWorkerTransferCount \+ 1/g), 1, "El handoff sólo puede incrementar una vez");

  for (const [block, stateName, label] of [
    [start, "$startState", "genérico"],
    [staged, "$DisposableSqlOwnershipState", "staged"],
  ]) {
    const handoff = `Set-PsqlDisposableWorkerOwnership -State ${stateName} -Worker $worker`;
    const handoffIndex = block.indexOf(handoff);
    const returnIndex = block.indexOf("return $worker", handoffIndex);
    assert.ok(handoffIndex >= 0 && returnIndex > handoffIndex, `Falta el handoff terminal ${label}`);
    assert.equal(block.slice(handoffIndex + handoff.length, returnIndex).trim(), "", `Nada ejecutable puede seguir al handoff ${label}`);
  }
  requireInOrder(start, ["Test-PsqlStartInfoContainsPgMaterial", "worker_pid_registration_incomplete", "Assert-PsqlDisposableFrozenIdentity", "worker_candidate_incomplete", "Set-PsqlDisposableWorkerOwnership", "return $worker"], "El start genérico debe agotar validaciones antes del handoff");
  requireInOrder(staged, ["StageA = $stageA", "StageB = $stageB", "$processStartState.LocalPidRecorded = $true", "$DisposableSqlOwnershipState.LocalPidRecorded = $true", "$processStartState.ExecutePidRecorded = $true", "$DisposableSqlOwnershipState.ExecutePidRecorded = $true", "Assert-Condition -Condition ($DisposableSqlOwnershipState.StartInfoMaterialClearAttempted", "ProcessIdObserved", "StdoutReadTask", "StderrReadTask", "ReferenceEquals($worker.Process", "Assert-PsqlDisposableFrozenIdentity", "Set-PsqlDisposableWorkerOwnership", "return $worker"], "El holder staged debe agotar validaciones antes del handoff");

  for (const token of ["PSQL_START_WORKER_OWNERSHIP_INTEGRITY", "complete_worker", "invalid_partial_worker", "Remove-DisposableWorkerSqlFile -Worker $State.Worker", "Complete-PsqlDisposableWorkerOwnership -State $State", "worker_owned_start_state_incomplete"]) assert.ok(startCleanup.includes(token), `Falta defensa de cleanup DB-26: ${token}`);
  requireInOrder(startCleanup, ["PSQL_START_PROCESS_TERMINATE", "ProcessTerminationObserved = $true", "PSQL_START_LOCAL_PID_REMOVE", "PSQL_START_EXECUTE_PID_REMOVE", "PSQL_START_DISPOSABLE_SQL_REMOVE"], "El cleanup DB-26 debe observar terminación antes de PID y SQL");
  assert.match(file, /\$null -eq \$worker -and \$DeleteSqlFileOnCompletion -and[\s\S]*?OwnerState -ceq "worker"[\s\S]*?PSQL_FILE_WORKER_HANDOFF_STATE[\s\S]*?psql_file_worker_handoff_state_rejected[\s\S]*?Stop-PsqlWorker -Worker \$ownershipState\.Worker/);
  assert.match(staged, /PrimaryErrorRecord[\s\S]*PrimaryFailureClass[\s\S]*PrimaryScenario/);
  assert.match(staged, /OwnerState -ceq "worker"[\s\S]*RUNTIME_HOLDER_WORKER_HANDOFF_CLEANUP[\s\S]*staged_runtime_holder_partial_worker_rejected/);

  requireInOrder(marker, [
    "$beforeReadTimestamp = Get-MonotonicTimestamp", "$beforeReadElapsed", "staged_runtime_holder_marker_timeout",
    "Read-StagedPsqlWorkerStreams", "$postReadMonotonicTimestamp = Get-MonotonicTimestamp",
    "$postReadElapsedMilliseconds", "$matches =", "staged_runtime_holder_marker_late_response_rejected",
    "$parts =", "$acceptedMonotonicTimestamp = Get-MonotonicTimestamp", "$acceptedElapsedMilliseconds",
    "staged_runtime_holder_marker_late_response_rejected", "Confirm-StagedWorkerStageA",
    "CommandElapsedMilliseconds", "SentMonotonicTimestamp", "ObservedMonotonicTimestamp",
  ], "El marcador DB-26 debe comprobar el deadline antes, después de leer y antes de aceptar");
  assert.equal(occurrences(marker, /staged_runtime_holder_marker_late_response_rejected/g), 2, "Deben existir dos cercos late-response");
  assert.doesNotMatch(marker, /TimeoutMilliseconds\s+\(\$TimeoutMilliseconds\s*\+\s*1\)/, "No puede aceptarse timeout + 1");
  assert.match(marker, /ObservedMonotonicTimestamp = \[long\]\$acceptedMonotonicTimestamp/);
  assert.doesNotMatch(marker, /ObservedMonotonicTimestamp\s*=\s*\[long\]\(Get-MonotonicTimestamp\)/);
  for (const field of ["HolderReadyMarkerObserved", "HolderReadyMarkerWithinDeadline", "HolderReleaseMarkerObserved", "HolderReleaseMarkerWithinDeadline"]) {
    const minimum = field.startsWith("HolderRelease") ? 9 : 8;
    assert.ok(occurrences(source, new RegExp(`${field}\\s*=`, "g")) >= minimum, `${field} debe derivarse en todos sus escenarios aplicables`);
    assert.match(pair, new RegExp(`\\$${field[0].toLowerCase()}${field.slice(1)}\\s*=`), `${field} debe derivarse independientemente en el par`);
  }

  for (const token of [
    "validate-db26-", "db26_successful_worker_transfer_rejected", "db26_worker_prevalidation_failure_atomic_rejected",
    "db26_synthetic_worker_post_mutation_invariant_failure", "db26_worker_post_mutation_rollback_rejected",
    "db26_failed_transfer_cleanup_rejected", "db26_complete_worker_defensive_cleanup_rejected",
    "db26_staged_worker_model_rejected", "db26_staged_transfer_failure_cleanup_rejected", "db26_failed_termination_diagnostic_state_rejected",
    "db26_failed_termination_independent_finalizer_rejected", "db26_partial_worker_fail_closed_rejected",
    "db26_generic_worker_terminal_order_rejected", "db26_staged_worker_terminal_order_rejected",
    "db26_marker_999ms_rejected", "db26_marker_inclusive_1000ms_boundary_rejected",
    "staged_runtime_holder_marker_timeout", "staged_runtime_holder_marker_late_response_rejected",
    "db26_late_stage_a_advanced_rejected", "db26_parse_late_stage_a_advanced_rejected",
    "db26_timely_stage_b_rejected", "staged_runtime_holder_marker_duplicate_rejected",
    "staged_runtime_holder_marker_value_rejected", "db26_fixture_process_or_sql_residue_rejected",
    "$script:Db26FixtureStartAttemptCount -eq 0",
  ]) assert.ok(fixture.includes(token), `Falta fixture DB-26: ${token}`);
  assert.doesNotMatch(fixture, /Read-Host|Process\.Start|\.Start\(\)|pg_dump/i, "DB-26 no puede iniciar procesos ni pedir credenciales");
};

const validateExplicitApprovals = (source, ids) => {
  assert.doesNotMatch(source, /Add-ApprovedScenario|Approve-ScenarioResult[^\n]*-Ordinal/);
  assert.doesNotMatch(source, /foreach\s*\([^)]*\.\.[^)]*\)[\s\S]{0,120}Approve-ScenarioResult/);
  assert.doesNotMatch(source, /Invoke-[^\n]+\n\s*Approve-ScenarioResult[^\n]+\n\s*Approve-ScenarioResult/);
  assert.doesNotMatch(source, /INSTALLATION_GROUP|ROLLBACK_GROUP|RUNTIME_GROUP|FailureScenario\s+"FINAL_POSTCHECK"/);
  for (const id of ids) {
    const minimum = /^MS(?:18|19)_/.test(id) ? 2 : 3;
    assert.ok(occurrences(source, new RegExp(id, "g")) >= minimum, `${id} carece de ejecución/resultado explícitos`);
  }
  const wall = extractFunction(source, "Invoke-WallClockScenarios");
  assert.match(wall, /New-ScenarioResult -ScenarioId \$ScenarioId/);
  assert.match(wall, /runOne "MS18_PUBLISH_WALL_CLOCK_AFTER_WAIT"/);
  assert.match(wall, /runOne "MS19_SCHEDULE_WALL_CLOCK_AFTER_WAIT"/);
  const approve = extractFunction(source, "Approve-ScenarioResult");
  assert.match(approve, /Result\.Assertions\.Count -gt 0/);
  assert.match(approve, /Write-Manifest/);
  const evidence = extractFunction(source, "Get-ApprovedEvidenceLines");
  assert.match(evidence, /ApprovedResults\.Count -eq 24/);
  assert.match(evidence, /foreach \(\$result in @\(\$ApprovedResults \| Sort-Object Id\)\)/);
  assert.doesNotMatch(evidence, /foreach \(\$scenario in \$script:RequiredScenarios/);
  const resume = `${extractFunction(source, "Read-Manifest")}\n${extractFunction(source, "Assert-ManifestRecord")}`;
  assert.match(resume, /ApprovedScenarioResults/);
  assert.match(resume, /resume_completed_phase_result_missing/);
};

const validateManifestStateMachine = (source) => {
  const fresh = extractFunction(source, "New-Manifest");
  for (const field of ["HarnessVersion", "RunId", "SourceHead", "TargetClass", "RunStatus", "CompletedPhase", "ActivePhase", "ActiveScenario", "AttemptNumber", "MigrationSha256", "RollbackSha256", "HarnessSha256", "ApprovedScenarios", "ApprovedScenarioResults", "ExpectedDatabaseState", "BaselineFingerprint", "Post0011Fingerprint", "ExpectedDiagnosticCounts", "ExpectedActivityFixture", "InstallationFixtureId", "ActiveWorkerPids", "FailureCode", "EvidenceHashes"]) {
    assert.match(fresh, new RegExp(`\\b${field}\\s*=`), `El manifiesto omite ${field}`);
  }
  assert.match(fresh, /RunStatus = "ready"/);
  assert.match(fresh, /CompletedPhase = "NONE"/);
  assert.match(fresh, /EvidenceHashes = \$null/);

  const record = extractFunction(source, "Assert-ManifestRecord");
  assert.match(record, /\$completedPhase -ceq "NONE" -or \$completedIndex -ge 0/);
  assert.match(record, /manifest_run_id_path_mismatch/);
  assert.match(record, /Test-LowercaseSha256/);
  assert.match(record, /Test-NonnegativeInteger -Value \$Manifest\.AttemptNumber/);
  assert.match(record, /Assert-ExpectedDiagnosticCountsShape/);
  assert.match(record, /Assert-ExpectedActivityFixtureShape/);
  assert.match(record, /manifest_phase02_activity_fixture_id_mismatch/);
  assert.match(record, /manifest_post_phase02_activity_fixture_retained/);
  assert.match(record, /resume_scenario_duplicate_rejected/);
  assert.match(record, /resume_scenario_set_mismatch/);
  assert.match(record, /resume_scenario_timestamp_rejected/);
  assert.match(record, /resume_scenario_assertion_rejected/);
  assert.match(record, /resume_later_inactive_result_rejected/);
  assert.match(record, /resume_completed_phase_result_missing/);
  assert.match(record, /resume_active_scenario_not_next/);
  assert.match(record, /run_evidence_conflict_rejected/);
  assert.match(record, /rejection_finalization_incomplete/);
  assert.match(record, /approval_finalization_incomplete/);
  assert.match(record, /rejected_evidence_actual_hash_mismatch/);
  assert.match(record, /approved_evidence_actual_hash_mismatch/);
  assert.match(record, /approved_scenario_contract_rejected/);
  assert.match(record, /ready_completed_phase_rejected/);
  assert.match(record, /ready_fresh_history_rejected/);
  assert.match(record, /ready_fresh_boundary_state_rejected/);
  assert.match(record, /approved_active_worker_pids_rejected/);
  assert.match(record, /manifest_active_worker_pid_duplicate_rejected/);
  for (const status of ["ready", "running", "rejected", "approved"]) assert.match(record, new RegExp(`if \\(\\$runStatus -ceq "${status}"\\)`));
  assert.doesNotMatch(record, /if \(\$completedIndex -ge 2\)[\s\S]{0,300}elseif \(\[string\]\$Manifest\.RunStatus/);
  const nextPhase = extractFunction(source, "Get-NextRemotePhaseIndex");
  assert.match(nextPhase, /PHASE_01_READ_ONLY_BASELINE/);

  const read = extractFunction(source, "Read-Manifest");
  assert.match(read, /Assert-ManifestRecord/);
  assert.match(read, /ExpectedRunId \$expectedRunId/);
  assert.match(read, /HasRejectedEvidence/);
  assert.match(read, /HasApprovedEvidence/);
  assert.match(read, /Get-Sha256 -Path \$Paths\.Evidence/);

  const eligibility = extractFunction(source, "Assert-ManifestExecuteEligibility");
  assert.match(eligibility, /resume_incomplete_phase_rejected/);
  assert.match(eligibility, /resume_rejected_run_rejected/);
  assert.match(eligibility, /resume_run_not_ready/);
  assert.match(eligibility, /resume_completed_boundary_missing/);
  assert.match(eligibility, /\$completedIndex -ge 1 -and \$completedIndex -le 5/);
  assert.match(eligibility, /HasFinalPostcheckEvidence/);
  const resume = extractFunction(source, "Assert-ResumeContract");
  assert.match(resume, /Assert-ManifestExecuteEligibility/);
  assert.match(resume, /ExpectedDiagnosticCounts/);
  for (const count of ["FixturePeriods", "Activities", "AuditEvents", "OpenWorkers", "GrantedSem01AdvisoryLocks", "WaitingSem01AdvisoryLocks", "TotalSem01AdvisoryLocks", "TransientWorkerSqlFiles", "TemporaryObjects"]) assert.match(resume, new RegExp(`ExpectedDiagnosticCounts\\.${count}`));
  assert.match(resume, /Get-ActivityFixtureSnapshot/);
  assert.match(resume, /\$activityFixture\.Activities -eq 1 -and \$activityFixture\.MatchingRows -eq 1/);
  assert.match(resume, /\$activityFixture\.RowFingerprint -ceq \[string\]\$Manifest\.ExpectedActivityFixture\.RowFingerprint/);
  assert.match(resume, /resume_activity_fixture_fingerprint_rejected/);
  assert.match(resume, /IncludeResolver -IncludeBoundaryContract/);
  assert.match(resume, /Assert-WorkerPidSetsAgree/);
  assert.match(resume, /resume_workers_active/);

  const start = extractFunction(source, "Start-ManifestPhase");
  requireInOrder(start, ["RunStatus = \"running\"", "ActivePhase = $Phase", "ActiveScenario =", "Write-Manifest"], "El inicio de fase debe persistir el intento activo");
  assert.match(start, /AttemptNumber = \[int\]\$Manifest\.AttemptNumber \+ 1/);
  assert.doesNotMatch(start, /ExpectedDiagnosticCounts\s*=\s*\$null/);

  const complete = extractFunction(source, "Set-ManifestPhase");
  assert.match(complete, /Get-ScenarioIdsThroughPhase/);
  assert.match(complete, /phase_completion_scenario_set_rejected/);
  assert.match(complete, /phase_completion_assertion_rejected/);
  assert.match(complete, /ExpectedDiagnosticCounts/);
  assert.match(complete, /ExpectedActivityFixture/);
  assert.match(complete, /phase_completion_requires_evidence_finalizer/);
  assert.match(complete, /Assert-WorkerPidSetsAgree/);
  assert.match(complete, /phase_completion_workers_active/);
  assert.doesNotMatch(complete, /FixturePeriods = 0; Activities = 0; AuditEvents = 0/);
  requireInOrder(complete, ["CompletedPhase = $Phase", "ActivePhase = $null", "ActiveScenario = $null", "ExpectedDiagnosticCounts = $ExpectedDiagnosticCounts", 'RunStatus = "ready"', "Write-Manifest"], "La frontera durable debe declararse sólo al final");

  const approve = extractFunction(source, "Approve-ScenarioResult");
  assert.match(approve, /scenario_approval_not_next/);
  assert.match(approve, /ActiveScenario = \$phaseIds/);
  const execute = extractFunction(source, "Invoke-ExecuteMode");
  assert.equal(occurrences(execute, /Start-ManifestPhase/g), 6, "Cada fase remota debe abrir una frontera activa explícita");
  requireInOrder(execute, ["Read-Manifest", "Assert-ResumeContract", "ApprovedScenarioResults"], "La reanudación debe rechazar una fase incompleta antes de restaurar resultados");
  requireInOrder(execute, ["$caughtError = $_", "$failureScenarioResult = Invoke-SecondaryFailureOperation", "$terminalSnapshotResult = Invoke-SecondaryFailureOperation", "Test-ApprovedFinalizationStarted", "Invoke-ReadOnlyDatabasePostcheck", "Publish-RejectedEvidence", "Complete-RejectedManifest", "throw $caughtError"], "La finalización secundaria no debe reemplazar el ErrorRecord primario");
  assert.doesNotMatch(execute, /FailureScenario \$script:CurrentScenario/);
  assert.match(execute, /execute_completed_phase_rejected/);
  requireInOrder(execute, ["Invoke-Phase06FinalPostcheck", "Assert-FinalApprovedState", 'Write-Output "SEM01_0011_MULTISESSION|APPROVED"'], "El marcador final requiere releer y aprobar el manifiesto terminal");

  const rejectedEvidence = extractFunction(source, "Publish-RejectedEvidence");
  requireInOrder(rejectedEvidence, ["Get-TerminalArtifactInventory", "Test-ApprovedFinalizationStarted", "TotalPublishingArtifacts -eq 0", ".publishing", "Write-ExternalUtf8File", "Get-Sha256", "Move-Item", "return Get-Sha256 -Path $Paths.Failure"], "La evidencia rechazada debe publicarse de forma inmutable antes del manifiesto");
  assert.match(rejectedEvidence, /rejected_evidence_conflicts_with_approved/);
  const rejectedManifest = extractFunction(source, "Complete-RejectedManifest");
  requireInOrder(rejectedManifest, ["Get-Sha256 -Path $Paths.Failure", "$terminalManifest = Copy-ManifestRecord", 'RunStatus = "rejected"', "Assert-ManifestRecord -Manifest $terminalManifest", "Write-Manifest", "Read-Manifest"], "El manifiesto rechazado debe validarse antes de persistirse");
  assert.ok(rejectedManifest.indexOf("Write-Manifest") > rejectedManifest.indexOf("Assert-ManifestRecord -Manifest $terminalManifest"), "No puede persistirse rejected antes de validarlo");
  assert.match(rejectedManifest, /EvidenceHashes = \[ordered\]@\{ Rejected = \$RejectedEvidenceHash \}/);

  const fixtures = extractFunction(source, "Assert-ManifestContractFixtures");
  for (const marker of ["CompletedPhase \"NONE\"", "PHASE_01_READ_ONLY_BASELINE", "PHASE_02_INSTALLATION_MATRIX", "PHASE_03_ROLLBACK_MATRIX", "PHASE_04_REAPPLY_0011", "PHASE_05_RUNTIME_MATRIX", "PHASE_06_FINAL_POSTCHECK", "MS11_OVERLAPPING_CREATIONS", "ready_completed_phase_rejected", "resume_completed_boundary_missing", "resume_approved_state_rejected", "approved_active_worker_pids_rejected", "manifest_active_worker_pid_duplicate_rejected", "resume_scenario_duplicate_rejected", "resume_later_inactive_result_rejected", "resume_rejected_run_rejected", "run_evidence_conflict_rejected", "manifest_phase02_activity_fixture_missing", "manifest_phase02_activity_fixture_id_mismatch", "manifest_post_phase02_activity_fixture_retained", "manifest_diagnostic_count_shape_rejected", "manifest_diagnostic_count_type_rejected_activities", "resume_running_phase_missing", "approved_evidence_missing", "rejected_evidence_missing", "manifest_run_id_path_mismatch"]) {
    assert.match(fixtures, new RegExp(marker));
  }
};

const validatePostcheckDiagnostic = (source) => {
  const postcheck = extractFunction(source, "Invoke-PostcheckOnlyMode");
  assert.doesNotMatch(postcheck, /Assert-ResumeContract|Approve-ScenarioResult|Write-Manifest|\.RunStatus\s*=/);
  assert.doesNotMatch(postcheck, /POSTCHECK_ONLY\|APPROVED/);
  requireInOrder(postcheck, ["Read-ManifestForDiagnostic", "Invoke-ReadOnlyDatabasePostcheck", "$stateMatches =", "$lines = Get-PostcheckDiagnosticLines", "Write-ExternalUtf8File", 'Write-Output "POSTCHECK_ONLY|DRIFT_OR_RESIDUE|$stableCode"', "Throw-StableFailure"], "PostcheckOnly debe escribir el diagnóstico antes de rechazar");
  const beforeDiagnostic = postcheck.slice(0, postcheck.indexOf("$lines ="));
  assert.doesNotMatch(beforeDiagnostic, /Assert-Condition[^\n]*\$stateMatches|Throw-StableFailure[^\n]*state_mismatch/);
  assert.match(postcheck, /POSTCHECK_ONLY\|CLEAN/);
  assert.match(postcheck, /POSTCHECK_ONLY\|DRIFT_OR_RESIDUE\|\$stableCode/);
  assert.match(postcheck, /\$fixtureCountMatches = \$expectedCountsAvailable -and \$postcheck\.FixturePeriods -eq/);
  assert.match(postcheck, /\$activityCountMatches = \$expectedCountsAvailable -and \$postcheck\.Activities -eq/);
  assert.match(postcheck, /\$auditCountMatches = \$expectedCountsAvailable -and \$postcheck\.AuditEvents -eq/);
  for (const count of ["OpenWorkers", "GrantedSem01AdvisoryLocks", "WaitingSem01AdvisoryLocks", "TotalSem01AdvisoryLocks", "TransientWorkerSqlFiles", "TemporaryObjects"]) {
    assert.match(postcheck, new RegExp(`\\$postcheck\\.${count} -eq \\$manifest\\.ExpectedDiagnosticCounts\\.${count}`));
  }
  assert.match(postcheck, /Get-ActivityFixtureSnapshot/);
  assert.match(postcheck, /\$protectedSourcesMatch = Test-ProtectedArtifactsMatch/);
  assert.match(postcheck, /\$terminalArtifacts = Get-TerminalArtifactInventory/);
  assert.match(postcheck, /\$terminalClassification = Get-TerminalArtifactClassification/);
  assert.match(postcheck, /\$evidenceContractMatches = \$terminalClassification\.EvidenceContractMatches/);
  assert.match(postcheck, /\$terminalArtifacts\.TotalPublishingArtifacts -eq 0/);
  assert.match(postcheck, /\$provenanceMatches = \$runIdMatches -and \$sourceHeadMatches -and \$migrationHashMatches -and \$rollbackHashMatches -and \$harnessHashMatches -and \$harnessVersionMatches/);
  const renderer = extractFunction(source, "Get-PostcheckDiagnosticLines");
  for (const marker of ["EXPECTED_DATABASE_STATE", "OBSERVED_DATABASE_STATE", "PARTIAL_STATE_REASON", "FINGERPRINT_AVAILABLE", "OBJECT_AUDIT_TABLE", "OBJECT_ADMIN_LIST", "OBJECT_CALENDAR_LOCK_HELPER", "OBJECT_PERIOD_RPCS", "OBJECT_TRIGGERS", "OBJECT_CONSTRAINTS", "DATABASE_STATE_COMPARISON", "CANONICAL_PERIOD_FINGERPRINT", "EXACT_AUTHORITY_FINGERPRINT", "EXACT_ASSIGNMENT_FINGERPRINT", "RESOLVER_FINGERPRINT", "POST0011_BOUNDARY_FINGERPRINT", "EXPECTED_FUNCTION_INVENTORY", "EXPECTED_TRIGGER_MATCHES", "AUDIT_CONSTRAINTS", "FIXTURE_PERIODS", "FIXTURE_ACTIVITIES", "PERIOD_AUDIT_EVENTS", "OPEN_WORKERS_REMOTE", "ACTIVE_WORKER_PIDS_MANIFEST", "ACTIVE_WORKER_PIDS_LOCAL_FILE", "GRANTED_SEM01_ADVISORY_LOCKS", "WAITING_SEM01_ADVISORY_LOCKS", "TOTAL_SEM01_ADVISORY_LOCKS", "TRANSIENT_WORKER_SQL_FILES", "TEMPORARY_DATABASE_OBJECTS", "EXPECTED_ACTIVITY_FIXTURE", "MANIFEST_RUN_ID", "MANIFEST_SOURCE_HEAD", "MANIFEST_MIGRATION_SHA256", "MANIFEST_ROLLBACK_SHA256", "MANIFEST_HARNESS_SHA256", "MANIFEST_HARNESS_VERSION", "PROTECTED_SOURCE_HASHES", "APPROVED_EVIDENCE_STATE", "APPROVED_POSTCHECK_PUBLISHING", "APPROVED_EVIDENCE_PUBLISHING", "FAILURE_POSTCHECK_PUBLISHING", "REJECTED_EVIDENCE_PUBLISHING", "TERMINAL_PUBLISHING_ARTIFACTS"]) {
    assert.match(renderer, new RegExp(marker));
  }
  assert.match(renderer, /Get-DiagnosticInventoryDisplayValue/);
  assert.match(extractFunction(source, "Get-DiagnosticInventoryDisplayValue"), /NOT_APPLICABLE/);
  for (const code of ["partial_database_state", "unknown_database_state", "database_state_mismatch"]) assert.match(postcheck, new RegExp(code));
  const classification = extractFunction(source, "Get-TerminalArtifactClassification");
  assert.match(classification, /\$approvedSide = \[bool\]\(\$Inventory\.ApprovedPostcheckExists -or \$Inventory\.ApprovedEvidenceExists -or \$approvedPublishing\)/);
  assert.match(classification, /\$rejectedSide = \[bool\]\(\$Inventory\.FailurePostcheckExists -or \$Inventory\.RejectedEvidenceExists -or \$rejectedPublishing\)/);
  assert.match(classification, /elseif \(\$rejectedSide -and \$RunStatus -cne "rejected"\) \{ "rejection_finalization_incomplete" \}/);
  for (const code of ["approval_publication_incomplete", "rejection_publication_incomplete", "ambiguous_terminal_artifacts", "approval_finalization_incomplete", "rejection_finalization_incomplete"]) assert.match(classification, new RegExp(code));
  assert.match(classification, /RunStatus -ceq "rejected"/);
  assert.match(classification, /-not \$Inventory\.FailurePostcheckExists -or \$Inventory\.FailurePostcheckMarkerValid/);

  const diagnostic = extractFunction(source, "Invoke-ReadOnlyDatabaseDiagnostic");
  assert.match(diagnostic, /DatabaseState = \[string\]\$phaseParts\[1\]/);
  assert.match(diagnostic, /FingerprintAvailable = \$false/);
  assert.match(diagnostic, /PartialStateReason/);
  for (const property of ["State", "PeriodHash", "PeriodIdentityHash", "ExactAuthorities", "SyntheticAuthorities", "AuthorityHash", "AssignmentHash", "ResolverHash", "BoundaryContractHash", "FunctionInventoryCount", "FunctionInventoryHash", "FunctionInventoryValid", "ExpectedTriggerMatchCount", "TriggerInventoryHash", "TriggerInventoryValid", "ConstraintInventoryHash", "AuditConstraintCount", "AuditConstraintInventoryValid", "IndexInventoryHash", "TableSecurityHash", "TableSecurityValid", "RoutineAclHash", "RoutineAclValid", "NonexistentHelperCount", "CalendarLockHelperCount", "AuditTable", "AdminList", "CompleteTriggerInventoryValid", "ActivitiesConstraintInventoryValid", "PeriodConstraintInventoryValid", "CompleteAuditConstraintInventoryValid", "CompleteIndexInventoryValid", "TableAclContractValid", "RlsContractValid", "PolicyContractValid"]) assert.match(diagnostic, new RegExp(`${property} = \\$null`));
  assert.doesNotMatch(diagnostic, /Get-DatabasePhase -/);
  const diagnosticFixtures = extractFunction(source, "Assert-DiagnosticContractFixtures");
  for (const marker of ["EXPECTED_FUNCTION_INVENTORY|NOT_APPLICABLE", "EXPECTED_TRIGGER_MATCHES|NOT_APPLICABLE", "AUDIT_CONSTRAINTS|NOT_APPLICABLE", "EXPECTED_FUNCTION_INVENTORY|18", "partial_diagnostic_write_before_rejection_fixture_rejected"]) assert.ok(diagnosticFixtures.includes(marker));
  const strictPhase = extractFunction(source, "Get-DatabasePhase");
  assert.match(strictPhase, /DatabaseState -in @\("POST0010", "POST0011"\)/);
};

const validatePhaseBoundaryContract = (source) => {
  const expected = extractFunction(source, "Get-ExpectedDiagnosticCountsForPhase");
  assert.match(expected, /PHASE_02_INSTALLATION_MATRIX/);
  assert.match(expected, /\$activities = if[\s\S]*\{ 1 \} else \{ 0 \}/);
  for (const field of ["FixturePeriods", "Activities", "AuditEvents", "OpenWorkers", "GrantedSem01AdvisoryLocks", "WaitingSem01AdvisoryLocks", "TotalSem01AdvisoryLocks", "TransientWorkerSqlFiles", "TemporaryObjects"]) assert.match(expected, new RegExp(`${field} =`));

  const phase02 = extractFunction(source, "Invoke-Phase02InstallationMatrix");
  requireInOrder(phase02, ["Get-ActivityFixtureSnapshot", "Activities -eq 1", "MatchingRows -eq 1", "RowFingerprint", "$expectedActivityFixture =", "Complete-OrchestrationCleanup", "InstallationFixtureId = $activityId", "ExpectedActivityFixture $expectedActivityFixture"], "PHASE_02 debe congelar una sola actividad completa después del cleanup");
  const snapshot = extractFunction(source, "Get-ActivityFixtureSnapshot");
  assert.match(snapshot, /select count\(\*\) from public\.activities/);
  assert.match(snapshot, /md5\(to_jsonb\(activity_row\)::text\)/);
  assert.match(snapshot, /where activity_row\.id = '\$ActivityId'::uuid/);

  const phase03 = extractFunction(source, "Invoke-Phase03RollbackMatrix");
  requireInOrder(phase03, ["InstallationFixtureId = $null", "ExpectedActivityFixture = $null", "Set-ManifestPhase"], "PHASE_03 debe limpiar el fixture antes de congelar la frontera");
  for (const phase of ["PHASE_01_READ_ONLY_BASELINE", "PHASE_03_ROLLBACK_MATRIX", "PHASE_04_REAPPLY_0011", "PHASE_05_RUNTIME_MATRIX"]) {
    assert.match(source, new RegExp(`Set-ManifestPhase[^\\n]*-Phase "${phase}"[^\\n]*[\\s\\S]{0,180}-ExpectedDiagnosticCounts`));
  }
};

const validateInstallation = (source) => {
  const phase = extractFunction(source, "Invoke-Phase02InstallationMatrix");
  requireInOrder(phase, ["Start-StagedInstallationHolder", 'Stage "A"', 'Marker "INSTALL_ACTIVITY_UPDATED"', "Start-PersistentInstallationObserver", 'Command "readiness"', "INSTALLATION_OBSERVER_READY|1", 'Command "holder_lock"', "INSTALLATION_HOLDER_LOCK|1", "Start-PsqlWorker", "Wait-ForInstallationWaitDirection", 'Stage "B"', 'Marker "INSTALL_PERIOD_READ"', 'Marker "INSTALL_HOLDER_COMMITTED"', "Wait-PersistentInstallationObserver", "Wait-StagedInstallationHolder", "Wait-PsqlWorker -Worker $migration", "InstallationMigrationCompletionTimeoutMilliseconds", "Get-ExactSessionDefaultIsolation", "Get-ExactRepositoryFileCompletedMarker", 'ExpectedState "POST0011"'], "MS01–MS05 deben derivarse de la secuencia controlada completa");
  assert.doesNotMatch(phase, /pg_sleep\s*\(/i);
  assert.doesNotMatch(phase, /Invoke-PsqlSql[\s\S]{0,400}(?:LOCK_OBSERVER|INSTALLATION_WAIT_DIRECTION)/);
  const migrationStart = phase.indexOf("$migration = Start-PsqlWorker");
  const holderRelease = phase.indexOf('Send-StagedInstallationHolderStage -Worker $holder -Stage "B"', migrationStart);
  assert.equal(occurrences(phase, /Send-StagedInstallationHolderStage -Worker \$(?:holder|phaseResources\.Holder) -Stage "B"/g), 2, "Stage B debe tener una transmisión normal y una recuperación condicionada");
  assert.ok(migrationStart >= 0 && holderRelease > migrationStart, "No se pudo delimitar la observación estructural");
  assert.doesNotMatch(phase.slice(migrationStart, holderRelease), /Invoke-PsqlSql|Start-PersistentInstallationObserver/);
  assert.match(phase, /\$stageARequest = Send-StagedInstallationHolderStage[\s\S]*-StageRequest \$stageARequest/);
  assert.match(phase, /\$stageBRequest = Send-StagedInstallationHolderStage[\s\S]*-StageRequest \$stageBRequest[\s\S]*InstallationHolderCommitBudgetMilliseconds/);
  assert.match(phase, /\$stageBRequest\.SentMonotonicTimestamp -ge \$installationObservation\.ObservedMonotonicTimestamp/);
  assert.match(phase, /Get-ServerClockStructuralTiming[\s\S]*ServerClockStructuralWaitThroughCommitWithinBudget/);
  assert.match(phase, /HolderCommitMarkerReceivedWithinControllerBudget/);
  assert.match(phase, /Test-TransactionMarkerOrdering/);
  assert.match(phase, /HolderProcessExitedZero/);
  assert.match(phase, /NoFixedSleepUsedAsProof = \$fixedHolderDelayAbsent/);
  assert.match(phase, /migration_installation_lock_timeout_rejected/);
  assert.doesNotMatch(phase, /Assert-ExpectedSqlState[^\n]*55P03|expected_lock_rejection/);
  assert.doesNotMatch(phase, /MigrationCompletedAfterHolder|CompletedAtUtc\s+-gt\s+\$holderResult\.CompletedAtUtc|MigrationCompletedInsideImmutableLockBudget|migrationElapsedAfterWaitMilliseconds/);
  assert.match(phase, /DefaultIsolation "repeatable read"/);
  assert.match(phase, /-EmitSessionIsolationMarker/);
  assert.match(phase, /-EmitRepositoryFileCompletedMarker/);
  assert.match(phase, /SameProcessDefaultIsolationWasRepeatableRead = \(\$migrationDefaultIsolation -ceq "repeatable read"\)/);
  assert.doesNotMatch(phase, /WorkerDefaultWasRepeatableRead\s*=\s*\$true|DefaultIsolationWasRepeatableRead\s*=\s*\$true/);
  assert.match(phase, /ExplicitReadCommittedPrecedesBaseline/);
  assert.match(phase, /ExactPost0011Postcondition/);
  assert.match(phase, /ZeroUnexpectedProcessTimeouts/);
  for (const assertion of [
    "StageACompletedWithinHardDeadline",
    "StageBSentAfterWaitDirection",
    "StageBMarkersCompletedWithinHardDeadline",
    "ObserverCommandCompletedWithinHardDeadline",
    "HolderAndMigrationAliveWhenObserved",
    "ServerClockTupleValid",
    "HolderCommitMarkerReceivedWithinControllerBudget",
    "ServerClockStructuralWaitThroughCommitWithinBudget",
    "MigrationCompletedWithinIndependentTimeout",
    "MigrationExitCodeZero",
    "MigrationNo55P03",
    "MigrationNoLockTimeoutText",
    "MigrationNo40P01",
    "ExactPost0011FingerprintCaptured",
    "ProtectedMigrationHashUnchanged",
  ]) assert.match(phase, new RegExp(assertion));
  assert.doesNotMatch(phase, /WaitObservedWithinInstallationDeadline\s*=\s*\$installationObservation\.WaitObserved/);
  assert.doesNotMatch(phase, /holderReleaseElapsedMilliseconds|HolderReleasedWithinApprovedBudget|CompletedAtUtc\s+-\s*\$installationObservation\.ObservedAtUtc/);
  assert.doesNotMatch(phase, /totalStructuralWaitUpperBoundMilliseconds|HolderCommitMarkerElapsedMilliseconds|StructuralLockAcquiredWithinImmutableBudget/);
  assert.doesNotMatch(phase, /ServerWaitAgeMilliseconds\s*\+\s*\$?holderCommitMarkerElapsedMilliseconds/i);
  assert.doesNotMatch(phase, /(?:LockQueryStart|Observation|CommitMarker)EpochMilliseconds\s*=/, "La evidencia agregada no debe persistir epochs crudos");
};

const validateRollback = (source) => {
  const phase = extractFunction(source, "Invoke-Phase03RollbackMatrix");
  const stageA = extractFunction(source, "Get-RollbackRelationHolderStageASql");
  const start = extractFunction(source, "Start-StagedRollbackRelationHolder");
  const genericStart = extractFunction(source, "Start-StagedRuntimeAdvisoryHolder");
  const send = extractFunction(source, "Send-StagedRollbackRelationHolderStage");
  const marker = extractFunction(source, "Wait-StagedRollbackRelationHolderMarker");
  const genericMarker = extractFunction(source, "Wait-StagedRuntimeAdvisoryHolderMarker");
  const observeSql = extractFunction(source, "Get-RollbackRelationHolderObservationSql");
  const evidence = extractFunction(source, "Test-ExactRollbackRelationHolderEvidence");
  const probe = extractFunction(source, "Invoke-RollbackRelationHolderObservationProbe");
  const wait = extractFunction(source, "Wait-ForExactRollbackRelationHolder");
  const absenceSql = extractFunction(source, "Get-RollbackRelationHolderAbsenceSql");
  const absence = extractFunction(source, "Wait-ForRollbackRelationHolderAbsence");
  const collect = extractFunction(source, "Wait-StagedRollbackRelationHolder");
  const stop = extractFunction(source, "Stop-StagedRollbackRelationHolder");
  const fixture = extractFunction(source, "Assert-Db27RollbackRelationHolderFixtures");
  const phase00 = extractFunction(source, "Invoke-Phase00Validate");

  assert.match(stageA, /begin;\nlock table public\.activities in row exclusive mode;\nselect 'MS06_ROLLBACK_HOLDER_LOCKED\|1';/);
  assert.doesNotMatch(stageA, /pg_sleep|^\s*(?:commit|rollback)\s*;/im);
  assert.match(start, /\$observedStageA -ceq \$expectedStageA/);
  assert.match(start, /Start-StagedRuntimeAdvisoryHolder/);
  for (const token of ["sitaa_sem01_rollback_holder", "MS06_ROLLBACK_HOLDER_LOCKED", "MS06_ROLLBACK_HOLDER_RELEASED"]) assert.match(start, new RegExp(token));
  assert.match(genericStart, /\$stageB = "rollback;`nselect '\$ReleaseMarker\|1';"/);
  assert.match(send, /Exact55P03Observed[\s\S]*PostRejectionHolderObserved[\s\S]*Post0011FingerprintPreserved/);
  assert.match(send, /ms06_rollback_holder_release_gate_rejected/);
  assert.match(send, /Send-StagedRuntimeAdvisoryHolderStage/);
  assert.match(marker, /Wait-StagedRuntimeAdvisoryHolderMarker/);
  requireInOrder(genericMarker, ["$beforeReadTimestamp = Get-MonotonicTimestamp", "$beforeReadElapsed", "Assert-HardMonotonicDeadline", "Read-StagedPsqlWorkerStreams", "$postReadMonotonicTimestamp = Get-MonotonicTimestamp", "$postReadElapsedMilliseconds", "staged_runtime_holder_marker_late_response_rejected", "$acceptedMonotonicTimestamp = Get-MonotonicTimestamp", "$acceptedElapsedMilliseconds", "staged_runtime_holder_marker_late_response_rejected"], "Los marcadores MS06 deben heredar los tres cercos monotónicos DB-26");
  for (const token of ["pg_stat_activity", "pg_locks", "sitaa_sem01_rollback_holder", "client backend", "idle in transaction", "public.activities", "RowExclusiveLock", "granted", "sitaa_sem01_rollback_contended", "ExpectedBackendPid"]) assert.match(observeSql, new RegExp(token.replaceAll(".", "\\.")));
  for (const token of ["ExactHolderCount -eq 1", "ExactBackendType", "IdleInTransaction", "ExactRelationLockCount -eq 1", "ContendedSessionCount -eq 0", "ExpectedBackendPid", "LocalHolderProcessAlive"]) assert.match(evidence, new RegExp(token.replaceAll("$", "\\$")));
  assert.match(evidence, /\(\$ExpectedBackendPid -eq 0 -or \$Evidence\.InternalHolderBackendPid -eq \$ExpectedBackendPid\)/);
  assert.match(probe, /Test-LocalPsqlWorkerAlive/);
  assert.match(probe, /ObserverProbeProcessTimeoutMilliseconds/);
  assert.match(wait, /Wait-ForObserverCondition/);
  assert.match(wait, /ContendedRollbackStartCount -eq 0/);
  assert.match(wait, /Test-ExactRollbackRelationHolderEvidence/);
  assert.match(absenceSql, /frozen_holder_lock_count/);
  assert.match(absenceSql, /ExpectedBackendPid/);
  assert.match(absence, /Wait-ForObserverCondition/);
  requireInOrder(collect, ["Wait-StagedInstallationHolder", "ProcessTerminationObserved", "Remove-DisposableWorkerSqlFile", "Complete-PsqlDisposableWorkerOwnership"], "La colección MS06 debe terminar el proceso antes de retirar SQL");
  requireInOrder(stop, ["Stop-StagedInstallationHolder", "ProcessTerminationObserved", "Remove-DisposableWorkerSqlFile", "Complete-PsqlDisposableWorkerOwnership"], "El stop MS06 debe conservar ownership y terminación");

  requireInOrder(phase, [
    "ROLLBACK_ELIGIBLE", "New-SqlFile", 'Label "rollback_relation_holder"', "Start-StagedRollbackRelationHolder",
    'Stage "A"', 'Marker "MS06_ROLLBACK_HOLDER_LOCKED"', "Wait-ForExactRollbackRelationHolder",
    "$holderBackendPid =", "$contendedRollbackStartCount++", "Invoke-ExactRepositorySqlFileResult",
    'DefaultIsolation "repeatable read"', "Get-ExactSessionDefaultIsolation -Result $contended",
    "rollback_contended_attempt_unexpected_success", "rollback_contended_attempt_unexpected_timeout",
    "$contendedAttemptHadNoDeadlock", 'SqlState "55P03"', 'ExpectedState "POST0011"',
    "Assert-FingerprintPreserved -Observed $stillApplied", "Wait-ForExactRollbackRelationHolder",
    "-ExpectedBackendPid $holderBackendPid", 'Stage "B"', 'Marker "MS06_ROLLBACK_HOLDER_RELEASED"',
    "Wait-ForRollbackRelationHolderAbsence", "Wait-StagedRollbackRelationHolder", "RequireSessionAbsent $true",
    "$holderCleanupComplete", "Complete-OrchestrationCleanup", "Assert-Condition -Condition $holderCleanupComplete",
    "Invoke-ExactRepositorySqlFile", 'DefaultIsolation "repeatable read"',
    "Get-ExactSessionDefaultIsolation -Result $successfulRollback", 'ExpectedState "POST0010"',
    "Assert-FingerprintPreserved -Observed $postRollback", "Approve-ScenarioResult",
  ], "MS06 debe mantener el holder staged hasta la evidencia exacta y limpiarlo antes del rollback exitoso");
  assert.equal(occurrences(phase, /Send-StagedRollbackRelationHolderStage[^\n]*-Stage "B"/g), 1, "Stage B sólo puede enviarse una vez");
  assert.equal(occurrences(phase, /Invoke-ExactRepositorySqlFileResult/g), 1, "El rollback contendido exacto sólo puede iniciarse una vez");
  assert.match(phase, /\$holderReadyMarker = Wait-StagedRollbackRelationHolderMarker -Worker \$holder -Marker "MS06_ROLLBACK_HOLDER_LOCKED"/);
  assert.match(phase, /\$holderReadiness = Wait-ForExactRollbackRelationHolder[\s\S]*?-ContendedRollbackStartCount \$contendedRollbackStartCount/);
  assert.equal(occurrences(phase, /Wait-ForExactRollbackRelationHolder/g), 2, "MS06 requiere readiness y observación post-rechazo separadas");
  assert.doesNotMatch(phase, /pg_sleep\s*\(|Start-Sleep|Start-PsqlWorker|ROLLBACK_LOCK_HELD/i);
  assert.match(phase, /if \(\$contended\.ExitCode -eq 0[\s\S]*Get-DatabasePhase[\s\S]*rollback_contended_attempt_unexpected_success/);
  assert.match(phase, /Assert-Condition -Condition \(-not \$contended\.TimedOut\) -Code "rollback_contended_attempt_unexpected_timeout"/);
  assert.match(phase, /\$contendedAttemptHadNoDeadlock = -not \(\$contendedOutput -match '\(\?i\)40P01\|deadlock detected'\)/);
  assert.match(phase, /PHASE03_CONTENDED_WORKER_COLLECTION[\s\S]*PHASE03_HOLDER_STOP[\s\S]*PHASE03_HOLDER_SQL_REMOVE/);
  assert.match(phase, /holderPostRejection\.Evidence\.InternalHolderBackendPid -eq \$holderBackendPid/);
  assert.match(phase, /holderPostRejection\.Evidence\.ExactRelationLockCount -eq 1/);
  assert.match(phase, /Get-TransientWorkerSqlFileCount[\s\S]*Get-WorkerPidManifestValues[\s\S]*ActiveWorkerPids/);
  assert.match(phase, /ContendedSameProcessDefaultIsolationWasRepeatableRead = \(\$contendedDefaultIsolation -ceq "repeatable read"\)/);
  assert.match(phase, /SuccessfulSameProcessDefaultIsolationWasRepeatableRead = \(\$successfulRollbackDefaultIsolation -ceq "repeatable read"\)/);
  for (const assertionName of [
    "EligibilityConfirmed", "HolderStageAObserved", "HolderStageAWithinDeadline", "ExactHolderSessionObserved",
    "ExactHolderRelationLockObserved", "ContendedRollbackStartedAfterHolderReady",
    "ContendedSameProcessDefaultIsolationWasRepeatableRead", "ContendedAttemptRejected55P03",
    "ContendedAttemptHadNoDeadlock", "SameHolderStillLockedAfterRejection", "ContendedAttemptLeftPost0011",
    "HolderReleasedOnlyAfter55P03", "HolderReleaseMarkerObserved", "HolderReleaseMarkerWithinDeadline",
    "HolderProcessCollected", "HolderTransientSqlRemoved", "SuccessfulSameProcessDefaultIsolationWasRepeatableRead",
    "ExplicitReadCommittedPrecedesEligibilityReads", "SecondAttemptCompleted", "SuccessfulRollbackCommitObserved",
    "ReadCommittedPinRestoredPost0010", "ZeroWorkerLockAndSqlResidue",
  ]) {
    assert.match(phase, new RegExp(`^    ${assertionName} =`, "m"), `Falta la aserción derivada ${assertionName}`);
    assert.doesNotMatch(phase, new RegExp(`^    ${assertionName} = \\$true`, "m"), `${assertionName} no puede estar fijada a true`);
  }
  assert.doesNotMatch(phase, /DefaultIsolationWasRepeatableRead\s*=\s*\$true/);
  assert.match(phase00, /Assert-Db26WorkerHandoffAndMarkerDeadlineFixtures[\s\S]*Assert-Db27RollbackRelationHolderFixtures/);
  for (const token of [
    "validate-db27-", "db27_fixed_stage_a_contract_rejected", "db27_verified_holder_artifact_rejected",
    "ms06_fixture_stage_b_gate_rejected", "ms06_fixture_stage_a_order_rejected", "SyntheticSchedulingDelayMilliseconds",
    "db27_holder_auto_release_fixture_rejected", "ms06_fixture_contended_start_gate_rejected",
    "ms06_fixture_exact_readiness_rejected", "db27_contended_exact_once_fixture_rejected",
    "ms06_fixture_wrong_sqlstate_rejected", "postgres_deadlock_40P01", "rollback_contended_attempt_unexpected_timeout",
    "ms06_fixture_same_holder_rejected", "rollback_contended_attempt_unexpected_success",
    "db27_unexpected_success_handling_fixture_rejected", "staged_runtime_holder_marker_timeout",
    "staged_runtime_holder_marker_duplicate_rejected", "staged_runtime_holder_marker_value_rejected",
    "db27_independent_cleanup_primary_preservation_rejected", "db27_fixture_final_residue_rejected",
  ]) assert.match(fixture, new RegExp(token), `Falta fixture DB-27: ${token}`);
  assert.doesNotMatch(fixture, /ProcessStartInfo|\.Start\(\)|Read-Host|Invoke-Psql\w*\s+-Connection|pg_dump/i, "Las fixtures DB-27 no pueden iniciar procesos ni acceder a PostgreSQL");
};

const validateInstallationTimingContract = (source, migrationSource) => {
  const immutableTimeout = parseInstallationMigrationLockTimeout(migrationSource);
  const statementTimeout = parseInstallationMigrationStatementTimeout(migrationSource);
  const constant = (name) => {
    const match = source.match(new RegExp(`\\$script:${name} = ([0-9]+)`));
    assert.ok(match, `Falta ${name}`);
    return Number(match[1]);
  };
  const declaredTimeout = constant("InstallationMigrationLockTimeoutMilliseconds");
  const declaredStatementTimeout = constant("InstallationMigrationStatementTimeoutMilliseconds");
  const waitAge = constant("InstallationWaitAgeLimitMilliseconds");
  const commit = constant("InstallationHolderCommitBudgetMilliseconds");
  const safety = constant("InstallationSafetyIntervalMilliseconds");
  const completion = constant("InstallationMigrationCompletionTimeoutMilliseconds");
  const holderExit = constant("InstallationHolderProcessExitTimeoutMilliseconds");
  const waitStart = constant("InstallationWaitStartDeadlineMilliseconds");
  const roundingTolerance = constant("InstallationServerClockRoundingToleranceMilliseconds");
  assert.equal(declaredTimeout, immutableTimeout);
  assert.equal(declaredStatementTimeout, statementTimeout);
  assert.equal(waitAge, 2000);
  assert.equal(commit, 2000);
  assert.ok(safety >= 1000 && safety < immutableTimeout);
  assert.equal(immutableTimeout - safety, 4000);
  assert.ok(roundingTolerance >= 0 && roundingTolerance <= 2);
  assert.ok(completion > statementTimeout && completion >= 130000 && completion <= 240000);
  assert.ok(holderExit >= 5000 && holderExit <= 30000);
  assert.ok(waitStart >= 10000 && waitStart <= 60000);
  const parser = extractFunction(source, "Get-InstallationMigrationTimeoutContractFromSource");
  assert.match(parser, /set local lock_timeout = '\(\[1-9\]\[0-9\]\*\)s'/);
  assert.match(parser, /set local statement_timeout = '\(\[1-9\]\[0-9\]\*\)s'/);
  assert.match(parser, /\$lockMatches\.Count -eq 1/);
  assert.match(parser, /\$statementMatches\.Count -eq 1/);
  assert.match(parser, /\$lockMilliseconds -eq 5000/);
  assert.match(parser, /\$statementMilliseconds -eq 120000/);
  const contract = extractFunction(source, "Assert-InstallationTimingContract");
  for (const marker of ["installation_wait_age_limit_rejected", "installation_holder_commit_budget_rejected", "installation_safety_interval_rejected", "installation_lock_budget_consumed", "installation_server_clock_tolerance_rejected", "installation_migration_completion_timeout_rejected", "installation_holder_process_exit_timeout_rejected", "installation_wait_start_deadline_contract_rejected"]) assert.match(contract, new RegExp(marker));
  assert.match(contract, /\$serverStructuralBudgetMilliseconds = \$MigrationLockTimeoutMilliseconds - \$SafetyIntervalMilliseconds/);
  assert.match(contract, /\$serverStructuralBudgetMilliseconds -eq 4000/);
  assert.doesNotMatch(contract, /\$WaitAgeLimitMilliseconds \+ \$HolderCommitBudgetMilliseconds/);
  const fixtures = extractFunction(source, "Assert-InstallationLockBudgetFixtures");
  assert.match(fixtures, /ReadAllText\(\$script:MigrationPath/);
  assert.match(fixtures, /statement_timeout/);
  assert.match(fixtures, /MigrationCompletionTimeoutMilliseconds 120000/);
};

const validatePersistentInstallationObserver = (source) => {
  const startInfo = extractFunction(source, "New-StagedPsqlStartInfo");
  assert.match(startInfo, /\[switch\]\$ReadOnly/);
  assert.match(startInfo, /default_transaction_read_only=on/);

  const sql = extractFunction(source, "Get-InstallationObserverSql");
  for (const token of [
    "INSTALLATION_OBSERVER_READY|1",
    "INSTALLATION_HOLDER_LOCK|",
    "INSTALLATION_WAIT_DIRECTION|1|",
    "ShareRowExclusiveLock",
    "RowExclusiveLock",
    "AccessExclusiveLock",
    "query_start",
    "lock_query_start_epoch_ms",
    "observation_epoch_ms",
    "clock_timestamp()",
    "sitaa_sem01_install_holder",
    "sitaa_sem01_install_migration",
  ]) assert.ok(sql.includes(token), `Observer persistente sin ${token}`);
  assert.match(sql, /lock\.mode = 'ShareRowExclusiveLock' and not lock\.granted/);
  assert.match(sql, /lock\.mode = 'RowExclusiveLock' and lock\.granted/);
  assert.match(sql, /lock\.mode = 'AccessExclusiveLock'/);
  assert.match(sql, /exactly_one_migration/);
  assert.match(sql, /exactly_one_holder/);
  assert.match(sql, /wait_age_ms::text \|\| '\|' \|\| lock_query_start_epoch_ms::text \|\| '\|' \|\| observation_epoch_ms::text/);
  assert.doesNotMatch(sql, /\[string\]\$Sql|Invoke-PsqlSql/);

  const start = extractFunction(source, "Start-PersistentInstallationObserver");
  assert.match(start, /New-StagedPsqlStartInfo/);
  assert.match(start, /-ReadOnly/);
  assert.match(start, /ReadLineAsync\(\)/);
  assert.match(start, /Update-WorkerPidManifest[\s\S]*Update-ExecuteWorkerManifest/);

  const send = extractFunction(source, "Send-PersistentInstallationObserverCommand");
  assert.match(send, /ValidateSet\("readiness", "holder_lock", "wait_direction"\)/);
  assert.match(send, /Get-InstallationObserverSql -Command \$Command/);
  requireInOrder(send, ["$startIndex =", "$sentMonotonicTimestamp = Get-MonotonicTimestamp", "StandardInput.Write", "Command = $Command", "StartIndex = $startIndex", "SentMonotonicTimestamp = [long]$sentMonotonicTimestamp"], "Cada solicitud debe congelar su instante monotonic antes del envio");
  assert.doesNotMatch(send, /\[string\]\$Sql/);

  const response = extractFunction(source, "Wait-PersistentInstallationObserverResponse");
  requireInOrder(response, [
    "$beforeReadTimestamp = Get-MonotonicTimestamp",
    "$beforeReadElapsed = Get-MonotonicElapsedMilliseconds",
    "Assert-HardMonotonicDeadline -ElapsedMilliseconds $beforeReadElapsed",
    "Read-StagedPsqlWorkerStreams",
    "$observedMonotonicTimestamp = Get-MonotonicTimestamp",
    "$commandElapsedMilliseconds = Get-MonotonicElapsedMilliseconds",
    "Assert-HardMonotonicDeadline -ElapsedMilliseconds $commandElapsedMilliseconds",
    "$matches =",
    "if ($matches.Count -eq 1)",
    "$acceptedMonotonicTimestamp = Get-MonotonicTimestamp",
    "$acceptedElapsedMilliseconds = Get-MonotonicElapsedMilliseconds",
    "Assert-HardMonotonicDeadline -ElapsedMilliseconds $acceptedElapsedMilliseconds",
    "return [pscustomobject]@{",
  ], "La respuesta persistente debe comprobar el deadline antes y despues de leer y antes de retornar");
  assert.match(response, /installation_observer_late_response_rejected/);
  assert.match(response, /\$matches\.Count -le 1/);
  assert.equal(occurrences(response, /Assert-HardMonotonicDeadline/g), 4);
  assert.match(response, /Assert-HardMonotonicDeadline -ElapsedMilliseconds \$acceptedElapsedMilliseconds -TimeoutMilliseconds \$TimeoutMilliseconds -FailureCode "installation_observer_late_response_rejected"/);
  for (const field of ["Line", "CommandElapsedMilliseconds", "SentMonotonicTimestamp", "ObservedMonotonicTimestamp", "ObservedAtUtc"]) assert.match(response, new RegExp(`${field} =`));

  const wait = extractFunction(source, "Wait-ForInstallationWaitDirection");
  requireInOrder(wait, ["Stopwatch", "InstallationWaitStartDeadlineMilliseconds", 'Command "wait_direction"', "InstallationObserverCommandTimeoutMilliseconds", "CommandElapsedMilliseconds", "InstallationWaitStartDeadlineMilliseconds", "Process.HasExited", "ConvertFrom-InstallationWaitDirectionMarker"], "La observacion debe aplicar deadlines individuales y globales y conservar workers vivos");
  assert.match(wait, /INSTALLATION_WAIT_PENDING\|1/);
  assert.match(wait, /\$response\.CommandElapsedMilliseconds -ge 0 -and \$response\.CommandElapsedMilliseconds -le \$commandTimeout/);
  assert.match(wait, /-not \$Holder\.Process\.HasExited -and -not \$Migration\.Process\.HasExited/);

  const parser = extractFunction(source, "ConvertFrom-InstallationWaitDirectionMarker");
  assert.match(parser, /\$matches\.Count -eq 1/);
  assert.match(parser, /\$parts\.Count -eq 5/);
  assert.match(parser, /TryParse\(\$parts\[2\]/);
  assert.match(parser, /TryParse\(\$parts\[3\]/);
  assert.match(parser, /TryParse\(\$parts\[4\]/);
  assert.match(parser, /\$waitAge -ge 0 -and \$lockQueryStartEpoch -gt 0 -and \$observationEpoch -ge \$lockQueryStartEpoch/);
  assert.match(parser, /\$waitAge -le \$script:InstallationWaitAgeLimitMilliseconds/);
  assert.match(parser, /\$serverDelta = \$observationEpoch - \$lockQueryStartEpoch/);
  assert.match(parser, /InstallationServerClockRoundingToleranceMilliseconds/);

  const commitParser = extractFunction(source, "ConvertFrom-InstallationHolderCommitMarker");
  assert.match(commitParser, /\$matches\.Count -eq 1/);
  assert.match(commitParser, /\$parts\.Count -eq 3/);
  assert.match(commitParser, /TryParse\(\$parts\[2\]/);
  assert.match(commitParser, /\$commitMarkerEpoch -gt 0/);

  const structural = extractFunction(source, "Get-ServerClockStructuralTiming");
  assert.match(structural, /\$CommitMarkerEpochMilliseconds - \$Observation\.LockQueryStartEpochMilliseconds/);
  assert.match(structural, /InstallationMigrationLockTimeoutMilliseconds - \$script:InstallationSafetyIntervalMilliseconds/);
  assert.doesNotMatch(structural, /HolderCommitMarkerElapsedMilliseconds|ServerWaitAgeMilliseconds\s*\+/);

  const fixtures = extractFunction(source, "Assert-InstallationObserverContractFixtures");
  for (const token of ["999", "1001", "fixture_matching_marker_late_rejected", "fixture_absent_before_deadline_rejected", "fixture_marker_present_after_deadline_rejected", "fixture_stage_a_timely_marker_rejected", "fixture_stage_a_late_marker_rejected", "fixture_stage_b_commit_timely_marker_rejected", "fixture_stage_b_commit_late_marker_rejected", "INSTALLATION_WAIT_DIRECTION|1|750|1700000000000|1700000000750", "INSTALL_HOLDER_COMMITTED|1|1700000003999", "installation_wait_server_clock_inconsistent", "installation_pending_then_true_fixture_rejected", "installation_late_true_fixture_rejected", "installation_late_command_true_fixture_rejected", "installation_server_structural_3999_fixture_rejected", "installation_server_structural_4001_fixture_rejected", "installation_commit_server_clock_order_rejected", "installation_server_transport_interval_fixture_rejected", "installation_controller_server_budget_separation_fixture_rejected", "installation_completion_after_lock_budget_fixture_rejected", "installation_marker_order_negative_fixture_rejected", "installation_process_exit_independence_fixture_rejected", "installation_observer_sanitized_evidence_rejected"]) assert.ok(fixtures.includes(token), `Fixture del observador ausente: ${token}`);
};

const validateStagedInstallationHolder = (source) => {
  const startInfo = extractFunction(source, "New-StagedPsqlStartInfo");
  assert.match(startInfo, /RedirectStandardInput = \$true/);
  assert.match(startInfo, /New-PsqlStartInfo/);
  assert.doesNotMatch(startInfo, /ReadToEndAsync/);

  const start = extractFunction(source, "Start-StagedInstallationHolder");
  requireInOrder(start, ["begin;", "update public.activities", "INSTALL_ACTIVITY_UPDATED", "INSTALL_PERIOD_READ", "commit;", "INSTALL_HOLDER_COMMITTED", "clock_timestamp()"], "Las dos etapas y el marcador temporal post-COMMIT deben permanecer ordenados");
  assert.match(start, /ReadLineAsync\(\)/);
  assert.match(start, /Update-WorkerPidManifest[\s\S]*Update-ExecuteWorkerManifest/);
  assert.doesNotMatch(start, /\[string\]\$Sql|pg_sleep\s*\(/i);

  const send = extractFunction(source, "Send-StagedInstallationHolderStage");
  assert.match(send, /Get-StagedWorkerNextState/);
  requireInOrder(send, ["$sentMonotonicTimestamp = Get-MonotonicTimestamp", "StandardInput.Write", "StandardInput.Flush", "Stage = $Stage", "SentMonotonicTimestamp = [long]$sentMonotonicTimestamp"], "Cada etapa debe congelar su instante monotonic antes del envio");
  assert.match(send, /StandardInput\.Close/);

  const marker = extractFunction(source, "Wait-StagedInstallationHolderMarker");
  requireInOrder(marker, ["$beforeReadTimestamp = Get-MonotonicTimestamp", "Assert-HardMonotonicDeadline -ElapsedMilliseconds $beforeReadElapsed", "Read-StagedPsqlWorkerStreams", "$commandElapsedMilliseconds = Get-MonotonicElapsedMilliseconds", "Assert-HardMonotonicDeadline -ElapsedMilliseconds $commandElapsedMilliseconds", "$matches =", "if ($matches.Count -eq 1)", "$acceptedElapsedMilliseconds = Get-MonotonicElapsedMilliseconds", "Assert-HardMonotonicDeadline -ElapsedMilliseconds $acceptedElapsedMilliseconds", "return [pscustomobject]@{"], "Los marcadores del holder deben tener deadlines duros antes y despues de leer y antes de retornar");
  assert.match(marker, /matches\.Count -le 1/);
  assert.match(marker, /Confirm-StagedWorkerStageA/);
  assert.match(marker, /staged_worker_late_marker_rejected/);
  assert.match(marker, /staged_worker_marker_stage_request_rejected/);
  assert.match(marker, /ConvertFrom-InstallationHolderCommitMarker/);
  assert.equal(occurrences(marker, /Assert-HardMonotonicDeadline/g), 4);
  assert.match(marker, /Assert-HardMonotonicDeadline -ElapsedMilliseconds \$acceptedElapsedMilliseconds -TimeoutMilliseconds \$TimeoutMilliseconds -FailureCode "staged_worker_late_marker_rejected"/);
  for (const field of ["Marker", "Value", "CommandElapsedMilliseconds", "SentMonotonicTimestamp", "ObservedMonotonicTimestamp", "ObservedAtUtc"]) assert.match(marker, new RegExp(`${field} =`));
  assert.doesNotMatch(marker, /ReadToEndAsync\(\)\.Result/);

  const wait = extractFunction(source, "Wait-StagedInstallationHolder");
  requireInOrder(wait, ["Process.HasExited", "Test-StagedWorkerPidRemovalEligible", 'Operation "remove"'], "El PID temporal solo se retira tras terminar realmente");
  const fixtures = extractFunction(source, "Assert-StagedWorkerContractFixtures");
  for (const markerName of ["staged_worker_stage_b_rejected", "staged_worker_already_completed", "failed_staged_worker_untracked_before_termination", "terminated_staged_worker_remained_tracked"]) assert.match(fixtures, new RegExp(markerName));
};

const validateSameProcessIsolationMarker = (source) => {
  assert.match(source, /\$script:SessionIsolationMarkerSql = "select 'SESSION_DEFAULT_ISOLATION\|' \|\| pg_catalog\.current_setting\('default_transaction_isolation'\);"/);
  assert.match(source, /\$script:RepositoryFileCompletedMarkerSql = "select 'REPOSITORY_FILE_COMPLETED\|1';"/);
  const startInfo = extractFunction(source, "New-PsqlStartInfo");
  requireInOrder(startInfo, ['if ($EmitSessionIsolationMarker)', '" -c "', '" -f "', 'if ($EmitRepositoryFileCompletedMarker)', '" -c "'], "Los marcadores fijos deben cercar al -f protegido");
  assert.match(startInfo, /Quote-ProcessArgument -Value \$script:SessionIsolationMarkerSql/);
  assert.match(startInfo, /Quote-ProcessArgument -Value \$script:RepositoryFileCompletedMarkerSql/);
  const exact = `${extractFunction(source, "Invoke-ExactRepositorySqlFile")}\n${extractFunction(source, "Invoke-ExactRepositorySqlFileResult")}`;
  assert.equal(occurrences(exact, /-EmitSessionIsolationMarker/g), 2);
  assert.equal(occurrences(exact, /-SqlFile \$RepositorySqlFile/g), 2);
  assert.doesNotMatch(exact, /New-SqlFile|WriteAllText|Copy-Item|Get-Content/);
  const parser = extractFunction(source, "Get-ExactSessionDefaultIsolation");
  assert.match(parser, /\$lines\.Count -eq 1/);
  assert.match(parser, /\$lines\[0\] -ceq "SESSION_DEFAULT_ISOLATION\|repeatable read"/);
  assert.doesNotMatch(parser, /-match|Contains\(|IndexOf\(/);
  const completionParser = extractFunction(source, "Get-ExactRepositoryFileCompletedMarker");
  assert.match(completionParser, /\$lines\.Count -eq 1/);
  assert.match(completionParser, /REPOSITORY_FILE_COMPLETED\|1/);
  const fixtures = extractFunction(source, "Assert-SameProcessIsolationMarkerFixtures");
  requireInOrder(fixtures, ["New-PsqlStartInfo", ' -c ', ' -f ', "completedCommandIndex", "PGOPTIONS", "Get-ExactSessionDefaultIsolation", "Get-ExactRepositoryFileCompletedMarker"], "La fixture local debe conservar proceso, orden y parsers exactos");
  for (const markerName of ["session_marker_sanitized_evidence_rejected", "session_default_isolation_marker_rejected", "session_default_isolation_value_rejected"]) assert.match(fixtures, new RegExp(markerName));
};

const validatePgOptionsContract = (source) => {
  const encoder = extractFunction(source, "ConvertTo-PgOptionsValue");
  assert.match(encoder, /read committed/);
  assert.match(encoder, /repeatable read/);
  assert.match(encoder, /Replace\('\\', '\\\\'\)\.Replace\(' ', '\\ '\)/);
  assert.match(encoder, /pgoptions_value_control_character_rejected/);
  assert.match(encoder, /pgoptions_value_option_like_rejected/);
  assert.match(encoder, /pgoptions_isolation_rejected/);
  const startInfo = extractFunction(source, "New-PsqlStartInfo");
  assert.match(startInfo, /\[ValidateSet\("read committed", "repeatable read"\)\]\[string\]\$DefaultIsolation/);
  assert.match(startInfo, /\$encodedIsolation = ConvertTo-PgOptionsValue -Value \$DefaultIsolation/);
  assert.match(startInfo, /statement_timeout=\$StatementTimeoutMilliseconds/);
  assert.match(startInfo, /lock_timeout=\$LockTimeoutMilliseconds/);
  assert.match(startInfo, /default_transaction_isolation=\$encodedIsolation/);
  assert.doesNotMatch(startInfo, /default_transaction_isolation=\$DefaultIsolation/);
  assert.doesNotMatch(startInfo, /default_transaction_isolation=(?:read committed|repeatable read)/);
  assert.doesNotMatch(startInfo, /default_transaction_isolation=["']/);
  for (const name of ["Start-PsqlWorker", "Invoke-PsqlFile", "Invoke-PsqlSql", "Invoke-ExactRepositorySqlFile", "Invoke-ExactRepositorySqlFileResult"]) {
    assert.match(extractFunction(source, name), /\[ValidateSet\("read committed", "repeatable read"\)\]\[string\]\$DefaultIsolation/);
  }
  const fixtures = extractFunction(source, "Assert-PgOptionsContractFixtures");
  for (const marker of ["read\\ committed", "repeatable\\ read", "pgoptions_raw_isolation_fixture_rejected", "pgoptions_timeout_fixture_rejected", "pgoptions_credential_fixture_rejected", "serializable"]) assert.ok(fixtures.includes(marker));
};

const validateWallClockTimingContract = (source) => {
  assert.match(source, /\$script:WallClockMarginSeconds = 45/);
  assert.match(source, /\$script:WallClockHolderSeconds = 70/);
  assert.match(source, /\$script:WallClockObserverTimeoutMilliseconds = 55000/);
  assert.match(source, /\$script:WallClockWorkerTimeoutMilliseconds = 90000/);
  const timing = extractFunction(source, "Assert-WallClockTimingContract");
  assert.match(timing, /WallClockMarginSeconds -ge 45/);
  assert.match(timing, /WallClockHolderSeconds -ge \(\$script:WallClockMarginSeconds \+ 25\)/);
  assert.match(timing, /WallClockObserverTimeoutMilliseconds -gt \$marginMilliseconds/);
  assert.match(timing, /\$holderMilliseconds -gt \$script:WallClockObserverTimeoutMilliseconds/);
  assert.match(timing, /WallClockWorkerTimeoutMilliseconds -gt \$holderMilliseconds/);
  assert.equal(occurrences(timing, /WallClockSafetyIntervalMilliseconds/g), 3);
  const wait = extractFunction(source, "Wait-ForObserverCondition");
  assert.match(wait, /\[ValidateRange\(1, 600000\)\]\[int\]\$TimeoutMilliseconds/);
};

const validateGenericObserverContract = (source) => {
  const wait = extractFunction(source, "Wait-ForObserverCondition");
  const resolve = extractFunction(source, "Resolve-ObserverProbeOutcome");
  const shape = extractFunction(source, "Assert-ObserverProbeResultShape");
  assert.match(wait, /Get-MonotonicTimestamp/);
  assert.doesNotMatch(wait, /DateTime|UtcNow|AddMilliseconds/);
  assert.doesNotMatch(wait, /if \(& \$Probe\) \{ return \}/);
  requireInOrder(wait, ["$observerStartedTimestamp = Get-MonotonicTimestamp", "$probeStartedTimestamp = Get-MonotonicTimestamp", "$elapsedBeforeProbe = Get-MonotonicElapsedMilliseconds", 'Throw-StableFailure -Code "observer_deadline_rejected"', "$probeResult = & $Probe", "$probeCompletedTimestamp = Get-MonotonicTimestamp", "$probeElapsedMilliseconds = Get-MonotonicElapsedMilliseconds", "$totalElapsedMilliseconds = Get-MonotonicElapsedMilliseconds", "Assert-ObserverProbeResultShape", "Resolve-ObserverProbeOutcome", "if ($null -ne $decision) { return $decision }"], "El observer debe medir antes y después del probe antes de aceptar");
  for (const field of ["Satisfied", "TotalElapsedMilliseconds", "ProbeElapsedMilliseconds", "AttemptCount", "Evidence"]) assert.match(resolve, new RegExp(`${field} =`));
  for (const code of ["observer_probe_late_success_rejected", "observer_probe_failed", "observer_condition_not_observed"]) assert.match(resolve, new RegExp(code));
  assert.match(wait, /observer_deadline_rejected/);
  requireInOrder(resolve, ["if ($Satisfied)", "$ProbeElapsedMilliseconds -gt $ProbeTimeoutMilliseconds", "$TotalElapsedMilliseconds -gt $TimeoutMilliseconds", 'Throw-StableFailure -Code "observer_probe_late_success_rejected"', "return [pscustomobject]"], "Un true tardío debe rechazarse antes del retorno");
  assert.match(shape, /Test-ObjectProperty -Value \$ProbeResult -Name "Satisfied"/);
  assert.match(shape, /Test-ObjectProperty -Value \$ProbeResult -Name "Evidence"/);
  assert.match(shape, /observer_probe_failed/);
  const fixtures = extractFunction(source, "Assert-GenericObserverContractFixtures");
  for (const marker of ["TotalElapsedMilliseconds 999", "TotalElapsedMilliseconds 1001", "fixture_false_then_true", "fixture_false_then_late_true", "structured_fixture", "Assert-ObserverProbeResultShape -ProbeResult ([pscustomobject]@{ Satisfied = $true })"]) assert.ok(fixtures.includes(marker), `Falta fixture genérica: ${marker}`);
  const probe = extractFunction(source, "Invoke-AdvisoryPairObservationProbe");
  assert.match(probe, /StatementTimeoutMilliseconds \$script:ObserverProbeCommandTimeoutMilliseconds/);
  assert.match(probe, /LockTimeoutMilliseconds \$script:ObserverProbeCommandTimeoutMilliseconds/);
  assert.match(probe, /ProcessTimeoutMilliseconds \$script:ObserverProbeProcessTimeoutMilliseconds/);
  assert.doesNotMatch(probe, /StatementTimeoutMilliseconds 90000|ProcessTimeoutMilliseconds 90000/);
  const rollback = extractFunction(source, "Invoke-RollbackRelationHolderObservationProbe");
  assert.match(rollback, /Satisfied = \$satisfied/);
  assert.match(rollback, /Evidence = \$evidence/);
  assert.match(rollback, /ObserverProbeProcessTimeoutMilliseconds/);
  const wall = extractFunction(source, "Invoke-WallClockScenarios");
  assert.match(wall, /Satisfied = \(\$marker\[1\] -ceq "1"\); Evidence =/);
};

const validateAdvisoryPairContract = (source) => {
  const sql = extractFunction(source, "Get-AdvisoryPairObservationSql");
  for (const fragment of ["exact_holder_count", "exact_waiter_count", "holder_advisory_granted", "waiter_advisory_ungranted", "holder_alive", "waiter_alive", "pids_differ", "waiter_activities_row_exclusive_granted", "holder_activities_conflict_absent", "expected_holder_matched", "expected_waiter_matched", "temporary_assignment_absent", "ADVISORY_PAIR_STATE"]) assert.match(sql, new RegExp(fragment));
  assert.match(sql, /lock_info\.classid = \$\(\$script:Sem01AdvisoryKeyOne\)/);
  assert.match(sql, /lock_info\.objid = \$\(\$script:Sem01AdvisoryKeyTwo\)/);
  assert.equal(occurrences(sql, /lock_info\.objsubid = \$\(\$script:Sem01AdvisoryObjSubId\)/g), 2, "El par debe fijar objsubid en holder y waiter");
  assert.equal(occurrences(sql, /1 = \(\s*\n\s*select count\(\*\)/g), 2, "El par debe exigir una fila exacta por lado");
  assert.match(sql, /and lock_info\.granted/);
  assert.match(sql, /and not lock_info\.granted/);
  assert.match(sql, /exact_holder_count = 1 and exact_waiter_count = 1/);
  assert.match(sql, /exact_holder_count = 1 and exact_waiter_count = 1 and holder_advisory_granted and waiter_advisory_ungranted\s+and holder_alive and waiter_alive and pids_differ/);
  assert.match(sql, /backend_type = 'client backend'/);
  assert.match(sql, /holder\.pid <> waiter\.pid/);
  assert.match(sql, /relation = 'public\.activities'::regclass/);
  const test = extractFunction(source, "Test-ExactAdvisoryPairEvidence");
  for (const field of ["ExactHolderCount", "ExactWaiterCount", "HolderAdvisoryGranted", "WaiterAdvisoryUnGranted", "HolderAlive", "WaiterAlive", "HolderWaiterPidsDiffer", "InternalHolderBackendPid", "InternalWaiterBackendPid", "ExpectedHolderMatched", "ExpectedWaiterMatched"]) assert.match(test, new RegExp(field));
  const sanitize = extractFunction(source, "ConvertTo-SanitizedAdvisoryPairEvidence");
  assert.doesNotMatch(sanitize, /InternalHolderBackendPid|InternalWaiterBackendPid/);
  const pair = extractFunction(source, "Invoke-AdvisoryWaitPair");
  assert.match(pair, /Invoke-AdvisoryPairObservationProbe/);
  assert.match(pair, /Test-ExactAdvisoryPairEvidence/);
  assert.match(pair, /ExactHolderCount = \$sanitizedEvidence\.ExactHolderCount/);
  assert.match(pair, /HolderAdvisoryGranted = \$sanitizedEvidence\.HolderAdvisoryGranted/);
  assert.match(pair, /WaiterAdvisoryUnGranted = \$sanitizedEvidence\.WaiterAdvisoryUnGranted/);
  assert.match(pair, /if \(\$holderReadiness\.Satisfied -and \$sameHolderObservedInPair -and \$observation\.Satisfied -and/);
  const activity = extractFunction(source, "Invoke-ActivityConcurrencyScenarios");
  for (const field of ["ExactHolderAndWaiterSessionsObserved", "GrantedHolderAndUngrantedWaiterObserved", "HolderAndWaiterAlive", "RelationEvidenceBoundToExactPair"]) assert.match(activity, new RegExp(field));
  const calendar = extractFunction(source, "Invoke-CalendarConcurrencyScenarios");
  for (const field of ["ExactHolderAndWaiterSessionsObserved", "GrantedHolderAndUngrantedWaiterObserved", "HolderAndWaiterAlive"]) assert.match(calendar, new RegExp(field));
  const wall = extractFunction(source, "Invoke-WallClockScenarios");
  requireInOrder(wall, ["Invoke-AdvisoryPairObservationProbe", "$wallWaitObservation = Wait-ForObserverCondition", "Test-ExactAdvisoryPairEvidence", "CLOCK_STILL_FUTURE_AT_WAIT"], "La observación wall-clock inicial debe probar el par exacto antes de consultar el reloj");
  const runtime = extractFunction(source, "Invoke-Phase05RuntimeMatrix");
  assert.match(runtime, /RealWaitObservationsPresent = \(\$script:AdvisoryObservationCount -ge 10\)/);
  const fixtures = extractFunction(source, "Assert-RuntimeObservationContractFixtures");
  for (const marker of ["missing_holder", "duplicate_holder", "missing_granted_holder", "missing_ungranted_waiter", "same_pid", "runtime_observer_sanitization_fixture_rejected"]) assert.match(fixtures, new RegExp(marker));
};

const validateAdvisoryHolderReadinessContract = (source) => {
  const sql = extractFunction(source, "Get-AdvisoryHolderObservationSql");
  for (const fragment of ["holder_sessions", "exact_holder_count", "holder_alive", "exact_granted_holder_count", "internal_holder_pid", "ADVISORY_HOLDER_STATE"]) assert.match(sql, new RegExp(fragment));
  assert.match(sql, /backend_type = 'client backend'/);
  assert.match(sql, /lock_info\.classid = \$\(\$script:Sem01AdvisoryKeyOne\)/);
  assert.match(sql, /lock_info\.objid = \$\(\$script:Sem01AdvisoryKeyTwo\)/);
  assert.match(sql, /lock_info\.objsubid = \$\(\$script:Sem01AdvisoryObjSubId\)/);
  assert.match(sql, /exact_holder_count = 1 and holder_alive and exact_granted_holder_count = 1/);

  const exact = extractFunction(source, "Test-ExactAdvisoryHolderEvidence");
  for (const field of ["ExactHolderCount", "HolderAlive", "HolderAdvisoryGranted", "ExactGrantedHolderCount", "InternalHolderBackendPid", "LocalHolderProcessAlive"]) assert.match(exact, new RegExp(field));
  const probe = extractFunction(source, "Invoke-AdvisoryHolderObservationProbe");
  assert.match(probe, /Test-LocalPsqlWorkerAlive/);
  assert.match(probe, /TerminalFailureCode = "advisory_holder_process_exited_before_readiness"/);
  assert.match(probe, /StatementTimeoutMilliseconds \$script:ObserverProbeCommandTimeoutMilliseconds/);
  assert.match(probe, /LockTimeoutMilliseconds \$script:ObserverProbeCommandTimeoutMilliseconds/);
  assert.match(probe, /ProcessTimeoutMilliseconds \$script:ObserverProbeProcessTimeoutMilliseconds/);
  const wait = extractFunction(source, "Wait-ForExactAdvisoryHolder");
  requireInOrder(wait, ["WaiterStartCount -eq 0", "Wait-ForObserverCondition", "Invoke-AdvisoryHolderObservationProbe", "Test-ExactAdvisoryHolderEvidence"], "La readiness debe usar el observer genérico antes de permitir un waiter");
  assert.match(wait, /advisory_holder_readiness_not_observed/);
  const gate = extractFunction(source, "Start-AdvisoryWaiterAfterHolderReady");
  requireInOrder(gate, ["WaiterStartCount.Value -eq 0", "Test-ExactAdvisoryHolderEvidence", "$worker = & $StartOperation", "$WaiterStartCount.Value =", "$WaiterStartCount.Value -eq 1"], "El gate debe iniciar exactamente un waiter después de readiness");
  const same = extractFunction(source, "Test-SameAdvisoryHolderObservedInPair");
  assert.match(same, /InternalHolderBackendPid -eq \$PairEvidence\.InternalHolderBackendPid/);

  const pair = extractFunction(source, "Invoke-AdvisoryWaitPair");
  assert.doesNotMatch(pair, /Start-Sleep\s+-Milliseconds\s+800/);
  assert.equal(occurrences(pair, /Start-AdvisoryWaiterAfterHolderReady/g), 1);
  requireInOrder(pair, ["New-PairedTransientSqlOwnershipState", "try {", "$holderArtifact = New-SqlFile", "$pairResources.HolderSqlFile = $holderArtifact.Path", "$pairResources.HolderOwnershipState = $holderArtifact.OwnershipState", "$waiterArtifact = New-SqlFile", "$pairResources.WaiterSqlFile = $waiterArtifact.Path", "$pairResources.WaiterOwnershipState = $waiterArtifact.OwnershipState", "Start-StagedRuntimeAdvisoryHolder", 'Stage "A"', "Wait-StagedRuntimeAdvisoryHolderMarker", "$holderReadiness = Wait-ForExactAdvisoryHolder", "$frozenHolderBackendPid =", "Start-AdvisoryWaiterAfterHolderReady", "$observation = Wait-ForObserverCondition", "-ExpectedHolderBackendPid $frozenHolderBackendPid", "$sameHolderObservedInPair = Test-SameAdvisoryHolderObservedInPair"], "El par genérico debe congelar holder antes de iniciar y observar al waiter");
  assert.match(pair, /if \(\$holderReadiness\.Satisfied -and \$sameHolderObservedInPair -and \$observation\.Satisfied -and/);
  for (const field of ["HolderReadyBeforeWaiterStart", "SameHolderObservedInPair", "ExactHolderAndWaiterSessionsObserved", "GrantedHolderAndUngrantedWaiterObserved"]) assert.match(pair, new RegExp(`${field} =`));

  const wall = extractFunction(source, "Invoke-WallClockScenarios");
  assert.doesNotMatch(wall, /Start-Sleep\s+-Milliseconds\s+700/);
  assert.equal(occurrences(wall, /Start-AdvisoryWaiterAfterHolderReady/g), 1);
  requireInOrder(wall, ["$wallResources.HolderWorker = Start-PsqlWorker", "$holderReadiness = Wait-ForExactAdvisoryHolder", "$frozenHolderBackendPid =", "$wallResources.WaiterWorker = Start-AdvisoryWaiterAfterHolderReady", "$wallWaitObservation = Wait-ForObserverCondition", "$sameHolderObservedInPair = Test-SameAdvisoryHolderObservedInPair", "CLOCK_STILL_FUTURE_AT_WAIT", "CLOCK_CROSSED_WHILE_WAITING"], "Wall-clock debe probar holder antes del waiter y conservar el mismo backend");
  assert.match(wall, /session_info\.pid = \$frozenHolderBackendPid/);
  assert.match(wall, /session_info\.pid = \$frozenWaiterBackendPid/);
  for (const field of ["HolderReadyBeforeWaiterStart", "SameHolderObservedInPair", "ExactHolderAndWaiterSessionsObserved", "GrantedHolderAndUngrantedWaiterObserved"]) assert.match(wall, new RegExp(`${field} =`));

  const calendar = extractFunction(source, "Invoke-CalendarConcurrencyScenarios");
  const activity = extractFunction(source, "Invoke-ActivityConcurrencyScenarios");
  assert.ok(occurrences(`${calendar}\n${activity}`, /HolderReadyBeforeWaiterStart = \$[A-Za-z0-9]+\.HolderReadyBeforeWaiterStart/g) >= 7, "MS11–MS17 deben derivar readiness del resultado real");
  assert.ok(occurrences(`${calendar}\n${activity}`, /SameHolderObservedInPair = \$[A-Za-z0-9]+\.SameHolderObservedInPair/g) >= 7, "MS11–MS17 deben conservar el backend observado");
  const runtime = extractFunction(source, "Invoke-Phase05RuntimeMatrix");
  assert.match(runtime, /RealWaitObservationsPresent = \(\$script:AdvisoryObservationCount -ge 10\)/);

  const fixtures = extractFunction(source, "Assert-AdvisoryHolderReadinessFixtures");
  for (const marker of ["holder_not_ready", "duplicate_holder_sessions", "holder_without_granted_advisory", "holder_process_exited", "waiter_started_once", "advisory_readiness_changed_holder_fixture_rejected", "advisory_readiness_fixed_sleep_fixture_rejected", "advisory_readiness_start_order_fixture_rejected"]) assert.match(fixtures, new RegExp(marker));
};

const validateExactSem01AdvisoryIdentity = (source) => {
  assert.match(source, /\$script:Sem01AdvisoryObjSubId = 2/);
  const expectedPredicates = [
    ["Get-AdvisoryHolderObservationSql", 1],
    ["Get-AdvisoryPairObservationSql", 2],
    ["Invoke-WallClockScenarios", 2],
    ["Invoke-ReadOnlyDatabaseDiagnostic", 3],
    ["Get-BaselineProbeSql", 3],
  ];
  for (const [name, count] of expectedPredicates) {
    const block = extractFunction(source, name);
    const advisoryRows = occurrences(block, /locktype = 'advisory'/g);
    const objsubidRows = occurrences(block, /objsubid = \$\(\$script:Sem01AdvisoryObjSubId\)/g);
    assert.equal(advisoryRows, count, `${name} debe contener ${count} predicados advisory exactos`);
    assert.equal(objsubidRows, advisoryRows, `${name} no puede omitir objsubid en un predicado advisory`);
  }
  const rowTest = extractFunction(source, "Test-ExactSem01AdvisoryLockRow");
  for (const field of ["LockType", "ClassId", "ObjId", "ObjSubId", "Granted"]) assert.match(rowTest, new RegExp(field));
  assert.match(rowTest, /Sem01AdvisoryObjSubId/);
  const fixtures = extractFunction(source, "Assert-Db21AdvisoryStagingAndOwnershipFixtures");
  for (const marker of ["ObjSubId = 2", "ObjSubId = 1", "missingObjSubId", "db21_waiting_residue_fixture_rejected", "db21_granted_residue_fixture_rejected"]) assert.ok(fixtures.includes(marker), `Falta fixture DB-21: ${marker}`);
};

const validateAdvisoryResidueContract = (source) => {
  const diagnostic = extractFunction(source, "Invoke-ReadOnlyDatabaseDiagnostic");
  const baselineSql = extractFunction(source, "Get-BaselineProbeSql");
  const fingerprint = extractFunction(source, "Invoke-ReadOnlyFingerprint");
  const baseline = extractFunction(source, "Invoke-ReadOnlyBaseline");
  const expected = extractFunction(source, "Get-ExpectedDiagnosticCountsForPhase");
  const resume = extractFunction(source, "Assert-ResumeContract");
  const postcheck = extractFunction(source, "Invoke-PostcheckOnlyMode");
  const final = extractFunction(source, "Invoke-Phase06FinalPostcheck");
  for (const name of ["GrantedSem01AdvisoryLocks", "WaitingSem01AdvisoryLocks", "TotalSem01AdvisoryLocks"]) {
    for (const block of [diagnostic, fingerprint, expected, resume, postcheck, final]) assert.match(block, new RegExp(name), `${name} falta en un límite diagnóstico`);
  }
  assert.equal(occurrences(diagnostic, /locktype = 'advisory'/g), 3);
  assert.match(diagnostic, /and not lock\.granted/);
  assert.equal(occurrences(baselineSql, /locktype = 'advisory'/g), 3);
  assert.match(baselineSql, /and not lock\.granted/);
  assert.match(baselineSql, /total_advisory_count/);
  assert.doesNotMatch(source, /HeldAdvisoryLocks|HELD_SEM01_ADVISORY_LOCKS/);
  assert.match(baseline, /GrantedSem01AdvisoryLocks[\s\S]*WaitingSem01AdvisoryLocks[\s\S]*TotalSem01AdvisoryLocks/);
  assert.match(final, /final_advisory_residue_rejected/);
  assert.match(final, /GRANTED_SEM01_ADVISORY_LOCKS/);
  assert.match(final, /WAITING_SEM01_ADVISORY_LOCKS/);
  assert.match(final, /TOTAL_SEM01_ADVISORY_LOCKS/);
};

const validateStagedRuntimeHolderContract = (source) => {
  const start = extractFunction(source, "Start-StagedRuntimeAdvisoryHolder");
  const send = extractFunction(source, "Send-StagedRuntimeAdvisoryHolderStage");
  const marker = extractFunction(source, "Wait-StagedRuntimeAdvisoryHolderMarker");
  const stop = extractFunction(source, "Stop-StagedRuntimeAdvisoryHolder");
  const pair = extractFunction(source, "Invoke-AdvisoryWaitPair");
  const calendarSql = extractFunction(source, "Get-CalendarCorrectionHolderStageASql");
  const calendar = extractFunction(source, "Invoke-CalendarConcurrencyScenarios");
  const activity = extractFunction(source, "Invoke-ActivityConcurrencyScenarios");
  assert.doesNotMatch(`${start}\n${calendarSql}\n${calendar}\n${activity}`, /pg_sleep\s*\(/i);
  for (const markerName of ["MS11_HOLDER_OPERATION_READY", "MS12_HOLDER_OPERATION_READY", "MS13_HOLDER_OPERATION_READY", "MS14_HOLDER_OPERATION_READY", "MS15_HOLDER_OPERATION_READY", "MS16_HOLDER_OPERATION_READY", "MS17_HOLDER_OPERATION_READY"]) assert.match(`${calendar}\n${activity}`, new RegExp(markerName));
  assert.match(start, /StageA = \$stageA/);
  assert.match(start, /StageB = \$stageB/);
  assert.match(start, /DeleteSqlFileOnCompletion = \$true/);
  assert.match(start, /Invoke-StagedProcessStartFailureCleanup/);
  assert.match(start, /Update-WorkerPidManifest[\s\S]*Update-ExecuteWorkerManifest/);
  requireInOrder(start, ["StartInfoMaterialCleared", "LocalPidRecorded", "ExecutePidRecorded", "StdoutReadTask", "StderrReadTask", "Assert-PsqlDisposableFrozenIdentity", "Set-PsqlDisposableWorkerOwnership", "return $worker"], "El holder staged debe validar por completo y transferir al final");
  const stagedTransferNeedle = "Set-PsqlDisposableWorkerOwnership -State $DisposableSqlOwnershipState -Worker $worker";
  const stagedTransferIndex = start.indexOf(stagedTransferNeedle);
  const stagedReturnIndex = start.indexOf("return $worker", stagedTransferIndex);
  assert.ok(stagedTransferIndex >= 0 && stagedReturnIndex > stagedTransferIndex);
  assert.equal(start.slice(stagedTransferIndex + stagedTransferNeedle.length, stagedReturnIndex).trim(), "", "El holder staged sólo puede retornar después del handoff");
  assert.match(start, /OwnerState -ceq "worker"[\s\S]*RUNTIME_HOLDER_WORKER_HANDOFF_CLEANUP/);
  assert.match(start, /PrimaryFailureClass[\s\S]*PrimaryScenario/);
  assert.match(send, /Send-StagedInstallationHolderStage/);
  requireInOrder(marker, ["$beforeReadTimestamp = Get-MonotonicTimestamp", "$beforeReadElapsed", "staged_runtime_holder_marker_timeout", "Read-StagedPsqlWorkerStreams", "$postReadMonotonicTimestamp = Get-MonotonicTimestamp", "$postReadElapsedMilliseconds", "$matches =", "staged_runtime_holder_marker_late_response_rejected", "$parts =", "$acceptedMonotonicTimestamp = Get-MonotonicTimestamp", "$acceptedElapsedMilliseconds", "staged_runtime_holder_marker_late_response_rejected", "Confirm-StagedWorkerStageA", "CommandElapsedMilliseconds", "SentMonotonicTimestamp", "ObservedMonotonicTimestamp"], "El marcador runtime requiere deadlines pre-read, post-read y pre-return");
  assert.equal(occurrences(marker, /staged_runtime_holder_marker_late_response_rejected/g), 2, "El marcador debe distinguir late post-read y late pre-return");
  assert.doesNotMatch(marker, /ObservedMonotonicTimestamp\s*=\s*\[long\]\(Get-MonotonicTimestamp\)/, "El timestamp devuelto debe ser exactamente el ya comprobado");
  assert.match(stop, /Stop-StagedInstallationHolder[\s\S]*Remove-DisposableWorkerSqlFile/);
  assert.equal(occurrences(pair, /Start-AdvisoryWaiterAfterHolderReady/g), 1, "El waiter staged sólo puede iniciarse una vez");
  assert.equal(occurrences(pair, /Send-StagedRuntimeAdvisoryHolderStage[^\n]*-Stage "B"/g), 1, "Stage B sólo puede enviarse una vez");
  requireInOrder(pair, ['Stage "A"', "$holderReadyObservation = Wait-StagedRuntimeAdvisoryHolderMarker", "$holderReadiness = Wait-ForExactAdvisoryHolder", "Start-AdvisoryWaiterAfterHolderReady", "$observation = Wait-ForObserverCondition", "$sameHolderObservedInPair = Test-SameAdvisoryHolderObservedInPair", "if ($WaitForExpected55P03BeforeRelease)", "$waiterResult = Wait-PsqlWorker", 'SqlState "55P03"', 'Stage "B"', "$holderReleaseObservation = Wait-StagedRuntimeAdvisoryHolderMarker"], "El holder staged debe respetar readiness, par y liberación");
  assert.match(pair, /Test-LocalPsqlWorkerAlive -Worker \$pairResources\.HolderWorker/);
  assert.match(pair, /HolderReleasedAfterExpectedWaiterRejection/);
  assert.match(pair, /HolderReleasedAfterExactPair/);
  for (const field of ["HolderReadyMarkerObserved", "HolderReadyMarkerWithinDeadline", "HolderReleaseMarkerObserved", "HolderReleaseMarkerWithinDeadline"]) {
    const minimum = field.startsWith("HolderRelease") ? 9 : 8;
    assert.ok(occurrences(source, new RegExp(`${field}\\s*=`, "g")) >= minimum, `${field} debe derivarse en todos sus escenarios aplicables`);
  }
  assert.match(pair, /CommandElapsedMilliseconds -le \$script:ObserverTimeoutMilliseconds/);
  assert.match(pair, /staged_runtime_holder_ready_marker_deadline_rejected/);
  assert.match(pair, /staged_runtime_holder_release_marker_deadline_rejected/);
  assert.doesNotMatch(`${calendar}\n${activity}`, /CompletedAtUtc\s*-[gl][te]|Process\.HasExited\s*-[gl][te]/);
  assert.ok(occurrences(`${calendar}\n${activity}`, /HolderReleasedAfterExactPair =/g) >= 5);
  const fixtures = extractFunction(source, "Assert-Db21AdvisoryStagingAndOwnershipFixtures");
  for (const markerName of ["db21_release_before_55p03_fixture_rejected", "db21_waiter_success_before_release_fixture_rejected", "db21_release_before_pair_fixture_rejected", "db21_process_exit_chronology_fixture_rejected", "db21_runtime_fixed_sleep_fixture_rejected"]) assert.match(fixtures, new RegExp(markerName));
};

const validatePairedSqlLifecycleContract = (source) => {
  const state = extractFunction(source, "New-PairedTransientSqlOwnershipState");
  const ownership = extractFunction(source, "Set-TransientSqlWorkerOwnership");
  const remove = extractFunction(source, "Remove-UnownedTransientSqlFile");
  const count = extractFunction(source, "Get-TransientWorkerSqlFileCount");
  for (const field of ["HolderSqlFile", "WaiterSqlFile", "HolderWorker", "WaiterWorker", "HolderOwnershipState", "WaiterOwnershipState", "HolderSqlOwnedByWorker", "WaiterSqlOwnedByWorker"]) assert.match(state, new RegExp(field));
  assert.match(ownership, /OwnedByWorker/);
  requireInOrder(remove, ["ownershipState", 'OwnerState -cin @("starter", "worker")', "return", 'OwnerState -cin @("caller", "controller")', "Invoke-PsqlDisposableControllerCleanup"], "El cleanup paired no debe borrar SQL en escrow starter/worker");
  assert.match(count, /worker_\*\.sql/);
  assert.match(count, /Assert-DisposableWorkerSqlPath/);
  for (const name of ["Invoke-AdvisoryWaitPair", "Invoke-WallClockScenarios"]) {
    const block = extractFunction(source, name);
    requireInOrder(block, ["New-PairedTransientSqlOwnershipState", "try {", "$holderArtifact = New-SqlFile", "HolderSqlFile = $holderArtifact.Path", "HolderOwnershipState = $holderArtifact.OwnershipState", "$waiterArtifact = New-SqlFile", "WaiterSqlFile = $waiterArtifact.Path", "WaiterOwnershipState = $waiterArtifact.OwnershipState"], `${name} debe conservar el artefacto verificado de cada archivo`);
    assert.match(block, /Set-TransientSqlWorkerOwnership[\s\S]*-Role "Holder"/);
    assert.match(block, /Set-TransientSqlWorkerOwnership[\s\S]*-Role "Waiter"/);
    assert.match(block, /Remove-UnownedTransientSqlFile[\s\S]*-Role "Holder"/);
    assert.match(block, /Remove-UnownedTransientSqlFile[\s\S]*-Role "Waiter"/);
  }
  const wall = extractFunction(source, "Invoke-WallClockScenarios");
  requireInOrder(wall, ["$holderArtifact = New-SqlFile", "HolderSqlFile = $holderArtifact.Path", "HolderOwnershipState = $holderArtifact.OwnershipState", "$waiterArtifact = New-SqlFile", "WaiterSqlFile = $waiterArtifact.Path", "WaiterOwnershipState = $waiterArtifact.OwnershipState", "$fixtureCreationAttempted = $true", "New-RuntimeActivityFixture"], "Wall-clock debe cercar ambos archivos antes del fixture");
  assert.equal(occurrences(wall, /New-RuntimeActivityFixture/g), 1, "Wall-clock sólo puede crear un fixture tras cercar ambos SQL");
  const resume = extractFunction(source, "Assert-ResumeContract");
  const postcheck = extractFunction(source, "Invoke-PostcheckOnlyMode");
  const final = extractFunction(source, "Invoke-Phase06FinalPostcheck");
  for (const block of [resume, postcheck, final]) assert.match(block, /TransientWorkerSqlFiles/);
  assert.match(final, /Assert-Condition -Condition \(\$postcheck\.TransientWorkerSqlFiles -eq 0\) -Code "final_transient_sql_residue_rejected"/);
  assert.match(final, /final_transient_sql_residue_rejected/);
  assert.match(final, /TRANSIENT_WORKER_SQL_FILES/);
  const fixtures = extractFunction(source, "Assert-Db21AdvisoryStagingAndOwnershipFixtures");
  for (const marker of ["holder_file", "waiter_file", "fixture", "holder_start", "completed", "ProcessLaunched", "db21_second_file_failure_ownership_fixture_rejected", "db21_worker_owned_file_fixture_rejected", "db21_independent_cleanup_attempt_fixture_rejected", "db21_paired_sql_ownership_order_fixture_rejected"]) assert.match(fixtures, new RegExp(marker));
  const model = extractFunction(source, "Invoke-SyntheticPairedSqlOwnershipModel");
  assert.doesNotMatch(model, /ProcessStartInfo|\.Start\(\)|Read-Host|Invoke-Psql|pg_dump/);
};

const validateTransientSqlCreationContract = (source) => {
  const create = extractFunction(source, "New-SqlFile");
  const verify = extractFunction(source, "Assert-TransientSqlFileVerified");
  const cleanup = extractFunction(source, "Invoke-TransientSqlPathCleanup");
  const faultWriter = extractFunction(source, "Invoke-TransientSqlFixtureExclusiveWrite");
  const fixtures = extractFunction(source, "Assert-Db22TransientSqlCreationFixtures");
  const faultFixture = extractFunction(source, "Invoke-Db22ExpectedNewSqlFileFailure");
  const globalWriter = extractFunction(source, "Invoke-ExclusiveExternalFileWrite");
  const globalUtf8Writer = extractFunction(source, "Write-ExternalUtf8File");
  const phase00 = extractFunction(source, "Invoke-Phase00Validate");

  assert.doesNotMatch(extractParamBlock(create, "New-SqlFile"), /ScriptBlock|Fault|WriteOperation|RemovalOperation/);
  requireInOrder(create, [
    "Test-Path -LiteralPath $RunDirectory -PathType Container",
    "$Label -cmatch",
    "$path = [System.IO.Path]::GetFullPath",
    "Assert-DisposableWorkerSqlPath -SqlFile $path",
    '$canonicalContent = $Sql.Trim() + "`n"',
    "$creationState = [pscustomobject]@{",
    "ExpectedSha256 = Get-TextSha256 -Text $canonicalContent",
    "try {",
    "Write-ExternalUtf8File -Path $creationState.Path -Content $creationState.CanonicalContent -Exclusive",
    "$creationState.WriteCompleted = $true",
    "Assert-TransientSqlFileVerified -CreationState $creationState",
    "catch {",
    "$creationError = $_",
    "$creationScenario = [string]$script:CurrentScenario",
    "Invoke-TransientSqlPathCleanup -CreationState $creationState",
    "Complete-OrchestrationCleanup -PrimaryError $creationError",
    "$creationState.WriteCompleted -and $creationState.Verified",
    "New-PsqlVerifiedTransientArtifact",
    "return $artifact",
  ], "New-SqlFile debe congelar, escribir, verificar y limpiar antes de transferir ownership");
  assert.equal(occurrences(create, /return \$artifact/g), 1, "New-SqlFile sólo retorna el artefacto después de verificar");
  assert.doesNotMatch(create, /return \$creationState\.Path/, "New-SqlFile no puede degradar el artefacto a un pathname");
  assert.doesNotMatch(create, /return \$path\s*$/m);

  requireInOrder(verify, [
    "Assert-DisposableWorkerSqlPath",
    "Test-Path -LiteralPath $CreationState.Path -PathType Leaf",
    "$item.Length -gt 0",
    "ReadAllBytes",
    "$hasBom",
    "UTF8Encoding($false, $true)",
    "GetString($actualBytes)",
    "CanonicalContent",
    "ToBase64String($actualBytes)",
    "ToBase64String($expectedBytes)",
    "Get-Sha256 -Path $CreationState.Path",
    "$CreationState.ExpectedSha256",
    "$CreationState.Verified = $true",
  ], "La verificación transitoria debe ser estricta en ruta, bytes, UTF-8, contenido y hash");
  assert.match(verify, /transient_sql_bom_rejected/);
  assert.match(verify, /transient_sql_content_rejected/);
  assert.match(verify, /transient_sql_sha256_rejected/);
  assert.match(verify, /\$actualContent -ceq \[string\]\$CreationState\.CanonicalContent/);
  assert.match(verify, /\$actualSha256 -ceq \[string\]\$CreationState\.ExpectedSha256/);

  assert.ok(occurrences(cleanup, /Assert-DisposableWorkerSqlPath/g) >= 3, "Guard requerido antes de remover y comprobar ausencia");
  requireInOrder(cleanup, [
    "$CreationState.RemovalAttempted = $true",
    "Invoke-OrchestrationCleanup -EmitFailureMarkers",
    'Name = "TRANSIENT_SQL_PATH_GUARD"',
    'Name = "TRANSIENT_SQL_PATH_REMOVE"',
    "Assert-DisposableWorkerSqlPath",
    "Remove-Item -LiteralPath $CreationState.Path -Force",
    'Name = "TRANSIENT_SQL_PATH_ABSENT"',
    "-not (Test-Path -LiteralPath $CreationState.Path)",
    "$CreationState.SecondaryCleanupErrors",
    "$CreationState.RemovalSucceeded",
  ], "El cleanup transitorio debe estar cercado, ser independiente y probar ausencia");
  assert.match(cleanup, /transient_sql_cleanup_nonfile_rejected/);
  assert.match(cleanup, /transient_sql_cleanup_absence_rejected/);

  assert.match(faultWriter, /FileMode\]::CreateNew/);
  assert.match(faultWriter, /WriteAllBytes\(\$FullPath/);
  for (const code of ["writer_construction", "write", "flush", "disposal", "removal_failure"]) assert.match(faultWriter, new RegExp(code));
  assert.match(faultWriter, /Invoke-ExternalFileStateCleanup/);
  assert.match(faultWriter, /Complete-OrchestrationCleanup -PrimaryError \$writeError/);

  for (const token of [
    "validate-db22-", "New-SqlFile", "ReadAllBytes", "Get-TextSha256", "precreated_partial",
    "writer_construction", "write", "flush", "disposal", "content_mismatch", "hash_mismatch",
    "removal_failure", "writer_dispose_attempted", "stream_dispose_attempted",
    "db22_holder_partial_file_cleanup_fixture_rejected", "db22_waiter_partial_file_cleanup_fixture_rejected",
    "db22_secondary_cleanup_failure_record_fixture_rejected", "db22_primary_error_replaced_by_cleanup_fixture_rejected",
    "db22_successful_primary_failed_removal_fixture_rejected", "db22_fixture_directory_residue_rejected",
  ]) assert.match(`${fixtures}\n${faultFixture}`, new RegExp(token.replaceAll("*", "\\*")));
  assert.match(fixtures, /Get-TransientWorkerSqlFileCount -RunDirectory \$fixtureRoot\) -eq 0/);
  assert.match(fixtures, /\$null -ne \$holderFailure[\s\S]*?\$null -eq \$holderState\.WaiterSqlFile -and \$fixtureWorkerStartCount -eq 0 -and[\s\S]*?\(Get-TransientWorkerSqlFileCount -RunDirectory \$fixtureRoot\) -eq 0/);
  assert.match(fixtures, /\$null -ne \$waiterFailure[\s\S]*?\$null -eq \$waiterState\.WaiterSqlFile -and \$fixtureWorkerStartCount -eq 0 -and[\s\S]*?\(Get-TransientWorkerSqlFileCount -RunDirectory \$fixtureRoot\) -eq 0/);
  assert.match(fixtures, /Remove-UnownedTransientSqlFile -State \$waiterState -Role "Holder"/);
  assert.match(fixtures, /Remove-UnownedTransientSqlFile -State \$waiterState -Role "Waiter"/);
  assert.doesNotMatch(fixtures, /ProcessStartInfo|Process\.Start\(|Read-Host|Invoke-Psql(?:File|Sql)\b|pg_dump/);
  assert.match(phase00, /Assert-Db22TransientSqlCreationFixtures/);

  assert.doesNotMatch(globalWriter, /Remove-Item|Invoke-TransientSqlPathCleanup|TRANSIENT_SQL_PATH_REMOVE/);
  assert.doesNotMatch(globalUtf8Writer, /Remove-Item|Invoke-TransientSqlPathCleanup|TRANSIENT_SQL_PATH_REMOVE/);
  assert.match(source, /\.publishing/);
};

const validateAuthorityLossContract = (source) => {
  const start = extractFunction(source, "Start-StagedAuthorityLossHolder");
  const startInfo = extractFunction(source, "New-StagedPsqlStartInfo");
  assert.match(start, /New-StagedPsqlStartInfo/);
  assert.match(startInfo, /RedirectStandardInput = \$true/);
  assert.match(start, /ReadLineAsync/);
  assert.match(start, /MS20_HOLDER_LOCKED\|1/);
  assert.match(start, /MS20_HOLDER_RELEASED\|1/);
  assert.doesNotMatch(start, /pg_sleep/);
  const marker = extractFunction(source, "Wait-StagedAuthorityLossHolderMarker");
  assert.match(marker, /Get-MonotonicTimestamp/);
  assert.match(marker, /Assert-HardMonotonicDeadline/);
  assert.match(marker, /ms20_staged_late_marker_rejected/);
  const authority = extractFunction(source, "Invoke-AuthorityLossScenario");
  assert.doesNotMatch(authority, /pg_sleep\(8\)|TemporaryAssignmentRemovedBeforeRelease|AdvisoryWaitObserved = \$true/);
  assert.equal(occurrences(authority, /Send-StagedInstallationHolderStage -Worker \$holder -Stage "B"/g), 1, "MS20 sólo puede enviar Stage B una vez");
  assert.equal(occurrences(authority, /-RequireTemporaryAssignmentAbsent/g), 2, "MS20 debe exigir ausencia en la observación y en su validación");
  assert.equal(occurrences(authority, /Assert-NoRuntimeResidue/g), 1, "MS20 debe verificar una postcondición integral");
  requireInOrder(authority, ["TEMP_AUTHORITY_GRANTED", "Start-StagedAuthorityLossHolder", 'Send-StagedInstallationHolderStage -Worker $holder -Stage "A"', "MS20_HOLDER_LOCKED", "$waiter = Start-PsqlWorker", "$beforeRemovalObservation = Wait-ForObserverCondition", "TEMP_AUTHORITY_REMOVED", "$postRemovalObservation = Wait-ForObserverCondition", "RequireTemporaryAssignmentAbsent", "Test-Ms20ReleaseEligible", 'Send-StagedInstallationHolderStage -Worker $holder -Stage "B"', "MS20_HOLDER_RELEASED", 'SqlState "42501"', "Assert-NoRuntimeResidue"], "MS20 debe retirar autoridad y volver a observar el mismo bloqueo antes de liberar");
  for (const field of ["ExistingSyntheticNonAdminUsed", "TemporaryExactAuthorityCommitted", "ExactHolderAndWaiterObservedBeforeRemoval", "TemporaryAssignmentRemovalCommitted", "ExactHolderStillGrantedAfterRemoval", "ExactWaiterStillBlockedAfterRemoval", "AuthorityAbsentWhileWaiterBlocked", "HolderReleasedOnlyAfterPostRemovalObservation", "PostLockReauthorizationRejected42501", "ZeroPeriodAndAuditMutation", "BaselineAuthoritiesAndAssignmentsPreserved", "ZeroWorkerAndLockResidue"]) assert.match(authority, new RegExp(`${field} =`));
  assert.doesNotMatch(authority, /(?:TemporaryAssignmentRemovalCommitted|AuthorityAbsentWhileWaiterBlocked|HolderReleasedOnlyAfterPostRemovalObservation|ZeroPeriodAndAuditMutation) = \$true/);
  assert.match(authority, /Invoke-OrchestrationCleanup -EmitFailureMarkers/);
  assert.match(authority, /MS20_HOLDER_STOP/);
  assert.match(authority, /MS20_WAITER_STOP/);
  assert.match(authority, /if \(\$assignmentCreationAttempted -and \$assignmentId -cmatch '\^\[0-9a-f-\]\{36\}\$'\) \{/);
  assert.match(authority, /MS20_CLEANUP_ASSIGNMENT_ABSENT/);
  requireInOrder(authority, ["$scenarioError = $_", "$scenarioPrimaryScenario = [string]$script:CurrentScenario", "$authorityCleanup = Invoke-OrchestrationCleanup", "Complete-OrchestrationCleanup", "ms20_cleanup_postcondition_rejected", "Approve-ScenarioResult"], "MS20 debe limpiar antes de aprobar y preservar la atribución primaria");
};

const validateMs20CandidateSetContract = (source) => {
  const candidateSet = extractFunction(source, "Get-Ms20CandidateSetSql");
  for (const predicate of ["profile.account_status = 'active'", "profile.is_active", "profile.email like '%@example.invalid'", "assignment.role_code = 'technical_admin'", "assignment.scope_type = 'system'", "assignment.service_area = 'technical'", "assignment.program_id is null", "assignment.division_id is null"]) assert.match(candidateSet, new RegExp(predicate.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")));
  assert.equal(occurrences(source, /^function Get-Ms20CandidateSetSql\s*\{/gm), 1, "Debe existir una sola fuente canónica del predicado MS20");

  const baselineSql = extractFunction(source, "Get-BaselineProbeSql");
  assert.match(baselineSql, /\$ms20CandidateSetSql = Get-Ms20CandidateSetSql/);
  assert.match(baselineSql, /ms20_candidates as \([\s\S]*\$ms20CandidateSetSql/);
  assert.match(baselineSql, /selected_ms20_candidate as \([\s\S]*order by candidate\.id[\s\S]*limit 1/);
  for (const field of ["ms20_candidate_count", "ms20_candidate_set_hash", "ms20_selected_candidate_count", "ms20_candidates_all_synthetic", "ms20_candidates_exclude_exact_active_admins"]) assert.match(baselineSql, new RegExp(field));
  assert.match(baselineSql, /md5\(string_agg\(candidate\.id::text, E'\\n' order by candidate\.id\)\)/);

  const probe = extractFunction(source, "Invoke-Ms20CandidateSetProbe");
  assert.match(probe, /\$candidateSetSql = Get-Ms20CandidateSetSql/);
  assert.match(probe, /selected_ms20_candidate as \([\s\S]*order by candidate\.id[\s\S]*limit 1/);
  assert.match(probe, /MS20_CANDIDATE_STATE/);
  for (const field of ["CandidateCount", "CandidateSetHash", "SelectedCandidateCount", "SelectedCandidateId", "CandidatesAllSynthetic", "CandidatesExcludeExactActiveAdmins"]) assert.match(probe, new RegExp(`${field} =`));
  const state = extractFunction(source, "Assert-Ms20CandidateSetState");
  assert.match(state, /CandidateCount -ge 1/);
  assert.match(state, /Test-LowercaseMd5/);
  assert.match(state, /SelectedCandidateCount -eq 1/);
  const match = extractFunction(source, "Test-Ms20CandidateSetMatchesFrozen");
  assert.match(match, /return \(\$State\.CandidateCount -eq \$FrozenFingerprint\.Ms20CandidateCount/);
  assert.match(match, /CandidateCount -eq \$FrozenFingerprint\.Ms20CandidateCount/);
  assert.match(match, /CandidateSetHash -ceq \[string\]\$FrozenFingerprint\.Ms20CandidateSetHash/);

  const fingerprintShape = extractFunction(source, "Assert-FingerprintRecordShape");
  const fingerprintRecord = extractFunction(source, "ConvertTo-FingerprintRecord");
  const fingerprintPreserved = extractFunction(source, "Assert-FingerprintPreserved");
  for (const field of ["Ms20CandidateCount", "Ms20CandidateSetHash"]) {
    assert.match(fingerprintShape, new RegExp(field));
    assert.match(fingerprintRecord, new RegExp(`${field} = \\$Fingerprint\\.${field}`));
    assert.match(fingerprintPreserved, new RegExp(field));
  }
  const baseline = extractFunction(source, "Invoke-ReadOnlyBaseline");
  assert.match(baseline, /Ms20CandidateCount -ge 1/);
  assert.match(baseline, /Test-LowercaseMd5 -Value \$fingerprint\.Ms20CandidateSetHash/);
  assert.match(baseline, /Ms20SelectedCandidateCount -eq 1/);
  assert.match(baseline, /Ms20CandidatesAllSynthetic/);
  assert.match(baseline, /Ms20CandidatesExcludeExactActiveAdmins/);

  const authority = extractFunction(source, "Invoke-AuthorityLossScenario");
  assert.doesNotMatch(authority, /from public\.profiles profile[\s\S]{0,500}order by profile\.id limit 1/);
  assert.equal(occurrences(authority, /Invoke-Ms20CandidateSetProbe/g), 2, "MS20 debe sondear antes del grant y después del cleanup");
  requireInOrder(authority, ["$beforeCandidateState = Invoke-Ms20CandidateSetProbe", "$candidateSetUnchangedBeforeGrant = Test-Ms20CandidateSetMatchesFrozen", "$candidateId = [string]$beforeCandidateState.SelectedCandidateId", "TEMP_AUTHORITY_GRANTED", "TEMP_AUTHORITY_REMOVED", "Complete-OrchestrationCleanup", "$postCleanupCandidateState = Invoke-Ms20CandidateSetProbe", "$candidateSetRestoredAfterCleanup = Test-Ms20CandidateSetMatchesFrozen", "$scenarioResult = New-ScenarioResult", "Approve-ScenarioResult"], "MS20 debe congelar, usar y restaurar el mismo conjunto candidato");
  for (const field of ["CandidateSetPresentAtBaseline", "CandidateSetUnchangedBeforeGrant", "DeterministicCandidateSelected", "CandidateSetRestoredAfterCleanup"]) assert.match(authority, new RegExp(`${field} = \\$`));
  assert.doesNotMatch(authority, /(?:CandidateSetPresentAtBaseline|CandidateSetUnchangedBeforeGrant|DeterministicCandidateSelected|CandidateSetRestoredAfterCleanup) = \$true/);

  const readOnly = extractFunction(source, "Invoke-ReadOnlyProbeMode");
  assert.match(readOnly, /MS20_SYNTHETIC_NONADMIN_CANDIDATES\|\$\(\$baseline\.Ms20CandidateCount\)/);
  assert.match(readOnly, /MS20_CANDIDATE_SET\|APPROVED/);
  assert.doesNotMatch(readOnly, /SelectedCandidateId|candidateId|@example\.invalid/);
  const fixtures = extractFunction(source, "Assert-Ms20CandidateSetContractFixtures");
  for (const marker of ["CandidateCount = 0", "CandidateCount = 1", "CandidateCount = 2", "Select-DeterministicMs20CandidateId", "INVALID", "ms20_candidate_count_drift_fixture_rejected", "ms20_candidate_hash_drift_fixture_rejected", "ms20_candidate_restored_fixture_rejected", "MS20_SYNTHETIC_NONADMIN_CANDIDATES", "MS20_CANDIDATE_SET\|APPROVED", "ms20_candidate_identity_leak_fixture_rejected"]) assert.match(fixtures, new RegExp(marker));
};

const validateTerminalArtifactContract = (source) => {
  const paths = extractFunction(source, "New-RunPaths");
  assert.match(paths, /FinalPostcheck = Join-Path \$runDirectory "final-postcheck\.local\.txt"/);
  assert.match(paths, /FailurePostcheck = Join-Path \$runDirectory "failure-postcheck\.local\.txt"/);
  assert.doesNotMatch(paths, /Postcheck = Join-Path \$runDirectory "postcheck\.local\.txt"/);
  const inventory = extractFunction(source, "Get-TerminalArtifactInventory");
  for (const field of ["ApprovedPostcheckPublishing", "ApprovedEvidencePublishing", "FailurePostcheckPublishing", "RejectedEvidencePublishing", "TotalPublishingArtifacts"]) assert.match(inventory, new RegExp(field));
  for (const pathName of ["FinalPostcheck", "FailurePostcheck", "Evidence", "Failure"]) assert.match(inventory, new RegExp(`\\$Paths\\.${pathName} \\+ "\\.publishing"|\\$Paths\\.${pathName}`));
  const classification = extractFunction(source, "Get-TerminalArtifactClassification");
  requireInOrder(classification, ["$approvedSide -and $rejectedSide", "$approvedPublishing", "$rejectedPublishing", "$invalidMarker", '$approvedSide -and $RunStatus -cne "approved"', '$rejectedSide -and $RunStatus -cne "rejected"'], "La clasificación terminal debe priorizar ambigüedad y publicaciones parciales");
  const fixtures = extractFunction(source, "Assert-TerminalArtifactContractFixtures");
  for (const marker of ["approved_terminal_artifact_fixture_rejected", "rejected_terminal_artifact_fixture_rejected", "partial_approved_publication_fixture_rejected", "approval_publication_incomplete", "rejection_publication_incomplete", "ambiguous_terminal_artifacts"]) assert.match(fixtures, new RegExp(marker));
};

const validateRuntimeSemantics = (source) => {
  const isolation = extractFunction(source, "Invoke-IsolationScenarios");
  assert.equal(occurrences(isolation, /sqlstate '25000'/g), 3);
  assert.equal(occurrences(isolation, /sitaa_sem01_read_committed_required/g), 3);
  assert.match(isolation, /MS10_ADMIN_MUTATION/);
  assert.match(isolation, /MS10_ACTIVITY_DML/);
  assert.match(isolation, /MS10_PUBLISH/);
  const ms10 = isolation.slice(isolation.indexOf('Set-CurrentScenario -ScenarioId "MS10_'));
  assert.match(ms10, /correct_admin_academic_period/);
  assert.match(ms10, /update public\.activities/);
  assert.match(ms10, /publish_activity/);

  const calendar = extractFunction(source, "Invoke-CalendarConcurrencyScenarios");
  assert.match(calendar, /MS11_WINNER_RPC/);
  assert.match(calendar, /create_admin_academic_period\('2098-2'/);
  assert.match(calendar, /SqlState "55P03"/);
  assert.match(calendar, /MS12_CORRECTION_RPC/);
  assert.match(calendar, /correct_admin_academic_period/);

  const activity = extractFunction(source, "Invoke-ActivityConcurrencyScenarios");
  assert.doesNotMatch(activity, /where false/i);
  const ms13 = activity.slice(activity.indexOf('Set-CurrentScenario -ScenarioId "MS13_'), activity.indexOf('Set-CurrentScenario -ScenarioId "MS14_'));
  const ms14 = activity.slice(activity.indexOf('Set-CurrentScenario -ScenarioId "MS14_'), activity.indexOf('Set-CurrentScenario -ScenarioId "MS15_'));
  const ms17 = activity.slice(activity.indexOf('Set-CurrentScenario -ScenarioId "MS17_'));
  assert.match(ms13, /publish_activity\('\$ActivityId'::uuid\)/);
  assert.match(ms14, /set start_date = a\.start_date \+ 1/);
  assert.match(activity, /RequireWaiterActivitiesRelationLock/);
  assert.match(ms17, /get_academic_period_for_date/);
  assert.match(ms17, /MS17_PREVIEW_NULL/);
  assert.match(ms17, /IndependentResolverMatches/);

  const wall = extractFunction(source, "Invoke-WallClockScenarios");
  assert.doesNotMatch(wall, /publish_activity\(gen_random_uuid\(\)\)|actividad no existe/i);
  assert.match(wall, /New-RuntimeActivityFixture/);
  assert.match(source, /\$script:WallClockMarginSeconds = 45/);
  assert.match(source, /\$script:WallClockHolderSeconds = 70/);
  assert.match(source, /\$script:WallClockObserverTimeoutMilliseconds = 55000/);
  assert.match(source, /\$script:WallClockWorkerTimeoutMilliseconds = 90000/);
  assert.match(wall, /CLOCK_STILL_FUTURE_AT_WAIT/);
  assert.match(wall, /CLOCK_CROSSED_WHILE_WAITING/);
  assert.match(wall, /pg_catalog\.pg_stat_activity/);
  assert.match(wall, /pg_catalog\.pg_locks/);
  assert.match(wall, /and not lock_info\.granted/);
  assert.match(wall, /and lock_info\.granted/);
  assert.match(wall, /-TimeoutMilliseconds \$script:WallClockObserverTimeoutMilliseconds/);
  assert.match(wall, /\$startCrossedWhileWaiterBlocked = \(\$combinedMarker\.Count -eq 4 -and \$combinedMarker\[1\] -eq "1" -and \$combinedMarker\[2\] -eq "1"\)/);
  assert.match(wall, /\$holderStillHeldAdvisoryAtCrossing = \(\$combinedMarker\.Count -eq 4 -and \$combinedMarker\[3\] -eq "1"\)/);
  assert.match(wall, /SqlState "23514"/);
  assert.match(wall, /wall_clock_crossed_then_23514_elapsed_ms_/);
  requireInOrder(wall, ["Wait-ForObserverCondition -FailureCode ($Label + \"_wait_not_observed\")", "CLOCK_STILL_FUTURE_AT_WAIT", "$observeClockCrossingWhileWaiting =", "CLOCK_CROSSED_WHILE_WAITING", "Wait-ForObserverCondition -FailureCode ($Label + \"_clock_crossing_not_observed\")", "Wait-PsqlWorker -Worker $wallResources.HolderWorker"], "MS18/MS19 deben probar futuro, cruce con bloqueo y luego liberar el holder");
  assert.equal(occurrences(wall, /Wait-PsqlWorker -Worker \$wallResources\.HolderWorker/g), 1, "El holder wall-clock sólo puede esperarse después del marcador combinado");
  for (const assertion of ["RealAdvisoryWaitObserved", "StartStillFutureWhenWaitObserved", "StartCrossedWhileWaiterBlocked", "HolderStillHeldAdvisoryAtCrossing", "ExactFutureStartRejection23514", "FixtureRemainedUnmodified", "ZeroPersistedResidue"]) assert.match(wall, new RegExp(`${assertion} = \\$[a-zA-Z]`));
  assert.doesNotMatch(wall, /(?:RealAdvisoryWaitObserved|StartStillFutureWhenWaitObserved|StartCrossedWhileWaiterBlocked|ExactFutureStartRejection23514|FixtureRemainedUnmodified|ZeroPersistedResidue) = \$true/);

  const authority = extractFunction(source, "Invoke-AuthorityLossScenario");
  assert.doesNotMatch(authority, /set_config\('request\.jwt\.claim\.sub', gen_random_uuid/);
  assert.match(authority, /TEMP_AUTHORITY_GRANTED/);
  assert.match(authority, /ms20_holder/);
  assert.match(authority, /ms20_waiter/);
  assert.match(authority, /ms20_remove/);
  assert.match(authority, /SqlState "42501"/);
  assert.match(authority, /sitaa_sem01_admin_access_denied/);
};

const validateFingerprint = (source) => {
  const sql = extractFunction(source, "Get-BaselineProbeSql");
  for (const field of ["id", "code", "name", "starts_on", "ends_on", "is_active", "sort_order", "created_at", "updated_at"]) {
    assert.match(sql, new RegExp(`'${field}', period\\.${field}`));
  }
  assert.match(sql, /authority_hash/);
  assert.match(sql, /assignment_hash/);
  assert.match(sql, /resolver_hash/);
  assert.match(sql, /boundary_contract_hash/);
  assert.doesNotMatch(sql, /lock_activity_semester_domain_0011/);
  const requiredFunctions = [
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
    "deactivate_admin_academic_period(uuid,text)",
  ];
  for (const signature of requiredFunctions) assert.ok(sql.includes(`public.${signature}`), `Falta función crítica ${signature}`);
  for (const metadata of ["owner_name", "language_name", "volatility", "parallel_class", "prosecdef", "proconfig_text", "explicit_acl", "normalized_definition"]) {
    assert.match(sql, new RegExp(metadata));
  }
  const functionDefinitionBlock = sql.slice(sql.indexOf("selected_functions as"), sql.indexOf("function_rows as"));
  assert.match(functionDefinitionBlock, /replace\(replace\(pg_catalog\.pg_get_functiondef/);
  assert.doesNotMatch(functionDefinitionBlock, /regexp_replace\([^\n]*E'\\\\s\+'/);
  assert.doesNotMatch(sql, /regexp_replace\(pg_catalog\.pg_get_functiondef/);
  assert.match(sql, /select md5\(normalized_definition\) from selected_functions where signature = 'public\.get_academic_period_for_date\(date\)'/);
  const requiredTriggers = [
    "enforce_activity_writer_integrity_b2a", "set_activities_updated_at", "validate_activities_scheduled_state",
    "activities_sem01_lock_insert", "activities_sem01_lock_update",
    "academic_periods_guard_sem01", "academic_periods_guard_truncate_sem01",
    "academic_periods_set_updated_at_sem01",
    "academic_period_audit_events_guard_update_delete",
    "academic_period_audit_events_guard_truncate",
  ];
  for (const trigger of requiredTriggers) assert.match(sql, new RegExp(`'${trigger}'`));
  assert.match(sql, /relation_info\.relname in \('activities', 'academic_periods', 'academic_period_audit_events'\)/);
  assert.match(sql, /table_info\.relname in \('academic_periods', 'academic_period_audit_events'\)/);
  assert.match(sql, /expected_audit_constraints/);
  assert.match(sql, /expected_activities_constraints/);
  assert.match(sql, /select constraint_name, constraint_definition from expected_activities_constraints/);
  assert.match(sql, /expected_period_constraints_post0010/);
  assert.match(sql, /expected_period_constraints_post0011/);
  assert.match(sql, /select constraint_name, constraint_definition from expected_period_constraints_post0010/);
  assert.match(sql, /select constraint_name, constraint_definition from expected_period_constraints_post0011/);
  assert.match(sql, /academic_period_audit_events_payload_check/);
  assert.match(sql, /select constraint_name, constraint_definition from expected_audit_constraints/);
  assert.match(sql, /expected_period_indexes_post0010/);
  assert.match(sql, /expected_period_indexes_post0011/);
  assert.match(sql, /expected_audit_indexes/);
  assert.match(sql, /relacl/);
  assert.match(sql, /relrowsecurity/);
  assert.match(sql, /relforcerowsecurity/);
  assert.match(sql, /routine_acl_rows/);
  assert.match(sql, /expected_nonowner_acl/);
  assert.match(sql, /expected_nonowner_acl_post0010/);
  assert.match(sql, /\|grantor=' \|\| pg_catalog\.pg_get_userbyid\(expanded_acl\.grantor\)/);
  assert.match(sql, /expanded_acl\.grantor = selected\.proowner as grantor_is_owner/);
  assert.match(sql, /expected_nonowner_acl\(signature, grantor_is_owner, grantee_name, privilege_type, is_grantable\)/);
  assert.match(sql, /observed_nonowner_acl as \([\s\S]*select signature, grantor_is_owner, grantee_name, privilege_type, is_grantable[\s\S]*where grantee <> proowner/);
  assert.doesNotMatch(sql, /where grantee <> proowner[^\n]*not is_grantable/);
  assert.match(sql, /'authenticated', 'EXECUTE', false/);
  assert.match(sql, /'service_role', 'EXECUTE', false/);
  assert.match(sql, /grantee_name in \('PUBLIC', 'anon'\)/);
  assert.match(sql, /expected_activity_policies/);
  assert.match(sql, /expected_period_policy/);
  assert.match(sql, /expected_activity_acl/);
  assert.match(sql, /expected_period_acl_post0011/);
  assert.match(sql, /values \('authenticated','SELECT',false\), \('service_role','SELECT',false\)/);
  assert.match(sql, /not exists \(select 1 from table_acl_rows where relname = 'academic_period_audit_events'\)/);
  assert.match(sql, /function_inventory_count/);
  assert.match(sql, /end as function_inventory_valid,/);
  assert.match(sql, /end as trigger_inventory_valid,/);
  assert.match(sql, /as activities_constraint_inventory_valid,/);
  assert.match(sql, /end as period_constraint_inventory_valid,/);
  assert.match(sql, /end as audit_constraint_inventory_valid,/);
  assert.match(sql, /end as complete_index_inventory_valid,/);
  assert.match(sql, /end as rls_contract_valid,/);
  assert.match(sql, /as policy_contract_valid,/);
  assert.match(sql, /end as table_acl_contract_valid,/);
  assert.match(sql, /table_acl_contract_valid and rls_contract_valid and policy_contract_valid\) as table_security_valid/);
  assert.match(sql, /end as routine_acl_valid,/);
  for (const validity of ["complete_trigger_inventory_valid", "activities_constraint_inventory_valid", "period_constraint_inventory_valid", "complete_audit_constraint_inventory_valid", "complete_index_inventory_valid", "table_acl_contract_valid", "rls_contract_valid", "policy_contract_valid"]) assert.match(sql, new RegExp(validity));
  assert.match(sql, /nonexistent_helper_count/);
  assert.match(sql, /calendar_lock_helper_count/);
  const final = extractFunction(source, "Invoke-Phase06FinalPostcheck");
  assert.match(final, /Assert-FingerprintPreserved[\s\S]*BaselineFingerprint/);
  assert.match(final, /Assert-FingerprintPreserved[\s\S]*Post0011Fingerprint[\s\S]*IncludeResolver[\s\S]*IncludeBoundaryContract/);
  assert.match(final, /FixturePeriods -eq 0/);
  assert.match(final, /Activities -eq 0/);
  assert.match(final, /AuditEvents -eq 0/);
  assert.match(final, /FunctionInventoryCount -eq 18/);
  assert.match(final, /ExpectedTriggerMatchCount -eq 10/);
  assert.match(final, /AuditConstraintCount -eq 7/);
  assert.match(final, /TableSecurityValid -and \$postcheck\.RoutineAclValid/);
  assert.match(final, /NonexistentHelperCount -eq 0/);
  assert.match(final, /CalendarLockHelperCount -eq 1/);
  assert.match(final, /final_rejected_evidence_rejected/);
  requireInOrder(final, ["Approve-ScenarioResult", "Get-ApprovedEvidenceLines", "Publish-ApprovedEvidencePair", "$actualApprovedHash = Get-Sha256 -Path $Paths.Evidence", "$terminalManifest = Copy-ManifestRecord", 'CompletedPhase = "PHASE_06_FINAL_POSTCHECK"', 'RunStatus = "approved"', "Assert-ManifestRecord -Manifest $terminalManifest", "Write-Manifest", "Read-Manifest"], "La aprobación final debe publicar, medir y validar antes del manifiesto");
  assert.ok(final.indexOf("Write-Manifest") > final.indexOf("Assert-ManifestRecord -Manifest $terminalManifest"), "No puede persistirse approved antes de validarlo");
  const publish = extractFunction(source, "Publish-ApprovedEvidencePair");
  requireInOrder(publish, ["Get-TerminalArtifactInventory", "TotalPublishingArtifacts -eq 0", ".publishing", "Write-ExternalUtf8File", "Get-Sha256", "Move-Item", "Get-Sha256 -Path $Paths.FinalPostcheck"], "La pareja de evidencia debe escribirse, cerrarse, hashearse y renombrarse");
};

const validateRoutineAclExactFixtures = (source) => {
  const sql = extractFunction(source, "Get-BaselineProbeSql");
  const expectedRows = [
    ["public.get_academic_period_for_date(date)", true, "authenticated", "EXECUTE", false],
    ["public.get_academic_period_for_date(date)", true, "service_role", "EXECUTE", false],
    ["public.publish_activity(uuid)", true, "authenticated", "EXECUTE", false],
    ["public.publish_activity(uuid)", true, "service_role", "EXECUTE", false],
    ["public.list_admin_academic_periods(integer,integer)", true, "authenticated", "EXECUTE", false],
    ["public.create_admin_academic_period(text,date,date,boolean)", true, "authenticated", "EXECUTE", false],
    ["public.correct_admin_academic_period(uuid,text,date,date,text)", true, "authenticated", "EXECUTE", false],
    ["public.activate_admin_academic_period(uuid,text)", true, "authenticated", "EXECUTE", false],
    ["public.deactivate_admin_academic_period(uuid,text)", true, "authenticated", "EXECUTE", false],
  ];
  for (const [signature, owner, grantee, privilege, grantable] of expectedRows) {
    assert.ok(sql.includes(`('${signature}', ${owner}, '${grantee}', '${privilege}', ${grantable})`), `ACL canónica ausente: ${signature}/${grantee}`);
  }
  const post0011ExpectedBlock = sql.slice(sql.indexOf("expected_nonowner_acl(signature"), sql.indexOf("expected_nonowner_acl_post0010"));
  assert.equal(occurrences(post0011ExpectedBlock, /\('public\./g), 9, "El ACL post-0011 debe tener exactamente nueve grants noowner");
  assert.doesNotMatch(post0011ExpectedBlock, /'PUBLIC'|'anon'/);
  const canonical = new Set(expectedRows.map((row) => JSON.stringify(row)));
  const exact = (rows) => rows.length === canonical.size && rows.every((row) => canonical.has(JSON.stringify(row)));
  assert.ok(exact(expectedRows));
  const malformed = [
    expectedRows.map((row) => row[0].includes("normalize_sem01") ? row : row).concat([["public.normalize_sem01_reason_0011(text)", true, "service_role", "EXECUTE", true]]),
    expectedRows.map((row) => row[0].startsWith("public.create_admin") ? [row[0], true, "authenticated", "EXECUTE", true] : row),
    expectedRows.concat([["public.create_admin_academic_period(text,date,date,boolean)", true, "service_role", "EXECUTE", false]]),
    expectedRows.concat([["public.create_admin_academic_period(text,date,date,boolean)", true, "unexpected_role", "EXECUTE", false]]),
    expectedRows.slice(1),
    expectedRows.concat([["public.publish_activity(uuid)", true, "PUBLIC", "EXECUTE", false]]),
    expectedRows.concat([["public.publish_activity(uuid)", true, "anon", "EXECUTE", false]]),
  ];
  for (const rows of malformed) assert.equal(exact(rows), false, "La fixture ACL negativa no debe coincidir");
};

const validateTargetBoundary = (source, canonical) => {
  const refs = [...canonical.matchAll(/const EXPECTED_PROJECT_REF = "([a-z0-9]{20})";/g)];
  assert.equal(refs.length, 1);
  assert.ok(!source.includes(refs[0][1]), "No debe duplicarse la referencia LAB");
  const boundary = extractFunction(source, "Assert-LabConnectionBoundary");
  assert.match(boundary, /\$username -ceq \("postgres\." \+ \$ExpectedReference\)/);
  assert.match(boundary, /\.pooler\\\.supabase\\\.com\$/);
  assert.match(boundary, /\$Uri\.Port -eq 5432/);
  assert.match(boundary, /\$Uri\.AbsolutePath -ceq "\/postgres"/);
  assert.match(boundary, /sslmode=\(require\|verify-ca\|verify-full\)/);
  assert.match(boundary, /parts\.Count -eq 1/);
  assert.match(boundary, /IsNullOrEmpty\(\$Uri\.Fragment\)/);
  const fixtures = extractFunction(source, "Assert-TargetBoundaryContract");
  assert.equal(occurrences(fixtures, /postgresql:\/\//g), 9);
  assert.match(fixtures, /evil\.invalid/);
  assert.match(fixtures, /6543\/postgres/);
  assert.match(fixtures, /\/other\?sslmode/);
  assert.match(fixtures, /application_name=bad/);
};

const validateFailures = (source) => {
  const thrower = extractFunction(source, "Throw-StableFailure");
  for (const value of ["expected_business_rejection", "expected_lock_rejection", "baseline_rejection", "connection_failure", "worker_crash", "unexpected_timeout", "postgres_deadlock", "postcondition_rejection", "source_integrity_rejection"]) {
    assert.match(thrower, new RegExp(`"${value}"`));
  }
  const execute = extractFunction(source, "Invoke-ExecuteMode");
  assert.match(source, /\$script:CurrentScenario = \$null/);
  assert.doesNotMatch(source, /\$script:CurrentScenario = "MS01/);
  assert.match(execute, /\$failureScenario = if \(\$failureScenarioResult\.Succeeded\).*"NONE"/);
  requireInOrder(execute, ["catch {", "$caughtError = $_", "$candidateCode =", "$failureClass =", "$failureScenarioResult = Invoke-SecondaryFailureOperation", "$terminalSnapshotResult = Invoke-SecondaryFailureOperation", "Test-ApprovedFinalizationStarted", "$failurePostcheckResult = Invoke-SecondaryFailureOperation", "$rejectedEvidenceResult = Invoke-SecondaryFailureOperation", "$rejectedManifestResult = Invoke-SecondaryFailureOperation", "throw $caughtError"], "El ErrorRecord original debe congelarse antes de toda finalización secundaria");
  assert.match(execute, /\$caughtError\.Exception\.Data\["FailureClass"\]/);
  assert.doesNotMatch(execute.slice(execute.indexOf("$caughtError = $_")), /\$failureClass = if \(\$_/);
  assert.match(execute, /throw \$caughtError/);
  assert.equal(occurrences(execute, /Invoke-SecondaryFailureOperation/g), 6);
  assert.doesNotMatch(execute, /FailureClass "fail_closed"/);
  const fixture = extractFunction(source, "Assert-FrozenErrorRecordFixture");
  assert.match(fixture, /postgres_deadlock_40P01/);
  assert.match(fixture, /nested_diagnostic_failure/);
  assert.match(fixture, /postgres_deadlock/);
  const secondaryFixture = extractFunction(source, "Assert-SecondaryFailurePreservationFixtures");
  assert.equal(occurrences(secondaryFixture, /Invoke-SecondaryFailureOperation/g), 3);
  assert.match(secondaryFixture, /postgres_deadlock_40P01/);
  assert.match(secondaryFixture, /secondary_failure_false_rejected_manifest_fixture_rejected/);
  const scenarioFixture = extractFunction(source, "Assert-FailureScenarioContractFixtures");
  assert.equal(occurrences(scenarioFixture, /Get-FailureScenario/g), 3);
  assert.match(scenarioFixture, /phase_only_failure_scenario_fixture_rejected/);
  assert.match(extractFunction(source, "Approve-ScenarioResult"), /Write-Manifest[\s\S]*Clear-CurrentScenario/);
  assert.match(extractFunction(source, "Set-ManifestPhase"), /^function[\s\S]*Clear-CurrentScenario/);
  const rejectedEvidence = extractFunction(source, "Publish-RejectedEvidence");
  assert.match(rejectedEvidence, /if \(\$FailurePostcheckRecorded\) \{ "FAILURE_POSTCHECK\|RECORDED" \} else \{ "FAILURE_POSTCHECK\|NOT_RECORDED" \}/);
};

const validateOrchestrationCleanupContract = (source) => {
  const cleanup = extractFunction(source, "Invoke-OrchestrationCleanup");
  requireInOrder(cleanup, [
    "$secondaryErrors = New-Object System.Collections.ArrayList",
    "foreach ($cleanupOperation in @($CleanupOperations))",
    "Invoke-SecondaryFailureOperation -Operation $operation",
    "[void]$secondaryErrors.Add($name)",
    "Succeeded = ($secondaryErrors.Count -eq 0)",
    "SecondaryErrors = @($secondaryErrors)",
  ], "La limpieza debe intentar todas las operaciones y acumular errores secundarios");
  assert.match(cleanup, /\^\[A-Z0-9_\]\+\$/);
  assert.match(cleanup, /SECONDARY_CLEANUP\|/);
  assert.doesNotMatch(cleanup, /\bbreak\b|Select-Object -First 1/);

  const complete = extractFunction(source, "Complete-OrchestrationCleanup");
  requireInOrder(complete, [
    "if ($null -ne $PrimaryError)",
    "$script:CurrentScenario = $PrimaryScenario",
    "throw $PrimaryError",
    "$CleanupResult.Succeeded",
    "$CleanupResult.SecondaryErrors",
    '-FailureClass "postcondition_rejection"',
  ], "El error primario debe restaurar su escenario y preceder toda clasificación de cleanup exitoso");
  assert.doesNotMatch(complete, /Throw-StableFailure[\s\S]*if \(\$null -ne \$PrimaryError\)|throw ["']secondary/);

  const affected = [
    { name: "Invoke-Phase02InstallationMatrix", error: "$phaseError", scenario: "$phaseScenario", cleanup: "$phaseCleanup", code: "installation_orchestration_cleanup_rejected", names: ["PHASE02_HOLDER_STAGE_B", "PHASE02_HOLDER_COLLECT", "PHASE02_HOLDER_STOP", "PHASE02_MIGRATION_COLLECT", "PHASE02_MIGRATION_STOP", "PHASE02_OBSERVER_COLLECT", "PHASE02_OBSERVER_STOP"] },
    { name: "Invoke-Phase03RollbackMatrix", error: "$rollbackError", scenario: "$rollbackScenario", cleanup: "$rollbackCleanup", code: "rollback_holder_cleanup_rejected", names: ["PHASE03_HOLDER_STOP"] },
    { name: "Invoke-AdvisoryWaitPair", error: "$pairError", scenario: "$pairScenario", cleanup: "$pairCleanup", code: "advisory_pair_cleanup_rejected", names: ["ADVISORY_HOLDER_STOP", "ADVISORY_WAITER_STOP"] },
    { name: "Invoke-WallClockScenarios", error: "$scenarioError", scenario: "$scenarioPrimaryScenario", cleanup: "$wallCleanup", code: "wall_clock_cleanup_rejected", names: ["WALL_HOLDER_STOP", "WALL_WAITER_STOP", "WALL_FIXTURE_PROBE", "WALL_FIXTURE_REMOVE", "WALL_FIXTURE_VERIFY"] },
    { name: "Invoke-AuthorityLossScenario", error: "$scenarioError", scenario: "$scenarioPrimaryScenario", cleanup: "$authorityCleanup", code: "ms20_cleanup_rejected", names: ["MS20_HOLDER_STOP", "MS20_WAITER_STOP", "MS20_ASSIGNMENT_REMOVE"] },
    { name: "Invoke-Phase05RuntimeMatrix", error: "$phaseError", scenario: "$phasePrimaryScenario", cleanup: "$runtimeCleanup", code: "runtime_phase_cleanup_rejected", names: ["RUNTIME_FIXTURE_PROBE", "RUNTIME_FIXTURE_REMOVE", "RUNTIME_FIXTURE_VERIFY"] },
  ];
  for (const contract of affected) {
    const block = extractFunction(source, contract.name);
    assert.doesNotMatch(block, /\bfinally\s*\{/, `${contract.name} no puede limpiar directamente en finally`);
    assert.ok(block.includes(`${contract.error} = $null`), `${contract.name} no inicializa el ErrorRecord primario`);
    assert.match(block, new RegExp(`\\${contract.error.replace("$", "$")} = \\$_`));
    assert.ok(block.includes(`${contract.scenario} = [string]$script:CurrentScenario`), `${contract.name} no congela el escenario primario`);
    assert.ok(block.includes(`${contract.cleanup} = Invoke-OrchestrationCleanup -EmitFailureMarkers`), `${contract.name} no usa limpieza independiente`);
    assert.ok(block.includes(`Complete-OrchestrationCleanup -PrimaryError ${contract.error} -PrimaryScenario ${contract.scenario} -CleanupResult ${contract.cleanup}`), `${contract.name} no reenvía el ErrorRecord congelado`);
    assert.ok(block.includes(contract.code), `${contract.name} no define rechazo estable de cleanup`);
    for (const name of contract.names) assert.ok(block.includes(`Name = "${name}"`), `${contract.name} omite ${name}`);
  }

  const phase02 = extractFunction(source, "Invoke-Phase02InstallationMatrix");
  requireInOrder(phase02, ["$phaseBoundaryReady = $true", "$phaseCleanup = Invoke-OrchestrationCleanup", "Complete-OrchestrationCleanup", "installation_orchestration_cleanup_postcondition_rejected", "foreach ($phaseResult in @($phaseResults))", "Approve-ScenarioResult", "$Manifest.InstallationFixtureId = $activityId", "Set-ManifestPhase"], "PHASE_02 no puede aprobar antes de limpiar");
  const phase03 = extractFunction(source, "Invoke-Phase03RollbackMatrix");
  requireInOrder(phase03, ["$rollbackCleanup = Invoke-OrchestrationCleanup", "Complete-OrchestrationCleanup", "$successfulRollback =", "Approve-ScenarioResult", "Set-ManifestPhase"], "PHASE_03 debe limpiar el holder antes de continuar");
  const pair = extractFunction(source, "Invoke-AdvisoryWaitPair");
  requireInOrder(pair, ["$pairCleanup = Invoke-OrchestrationCleanup", "Complete-OrchestrationCleanup", "advisory_pair_collection_postcondition_rejected", "return $pairResult"], "El par advisory no puede retornar recursos activos");
  const wall = extractFunction(source, "Invoke-WallClockScenarios");
  for (const state of ["$fixtureCreationAttempted", "$fixtureCreated", "$wallCleanupState.FixtureRemoved"]) assert.ok(wall.includes(state), `Wall-clock omite estado ${state}`);
  requireInOrder(wall, ["$wallCleanup = Invoke-OrchestrationCleanup", "WALL_FIXTURE_VERIFY", "Complete-OrchestrationCleanup", "wall_clock_cleanup_postcondition_rejected", "Approve-ScenarioResult"], "MS18/MS19 no pueden aprobar antes de probar remoción");
  const authority = extractFunction(source, "Invoke-AuthorityLossScenario");
  requireInOrder(authority, ["$authorityCleanup = Invoke-OrchestrationCleanup", "Complete-OrchestrationCleanup", "ms20_cleanup_postcondition_rejected", "Approve-ScenarioResult"], "MS20 no puede aprobar antes del cleanup");
  const runtime = extractFunction(source, "Invoke-Phase05RuntimeMatrix");
  for (const state of ["$runtimeFixtureCreationAttempted", "$runtimeFixtureCreated", "$runtimeCleanupState.FixtureRemoved"]) assert.ok(runtime.includes(state), `PHASE_05 omite estado ${state}`);
  requireInOrder(runtime, ["$runtimeCleanup = Invoke-OrchestrationCleanup", "RUNTIME_FIXTURE_VERIFY", "Complete-OrchestrationCleanup", "runtime_phase_cleanup_postcondition_rejected", 'Set-CurrentScenario -ScenarioId "MS21_ADVISORY_OBSERVATION"'], "PHASE_05 no puede crear MS21 tras cleanup fallido");

  const fixtureRunner = extractFunction(source, "Invoke-OrchestrationCleanupFixture");
  requireInOrder(fixtureRunner, ["$primaryError = $null", "catch {", "$primaryError = $_", "$State.FrozenErrorRecord = $_", "Invoke-OrchestrationCleanup", "PrimaryErrorRecordPreserved", "Complete-OrchestrationCleanup"], "La fixture debe congelar el mismo ErrorRecord antes del cleanup");
  const fixtures = extractFunction(source, "Assert-OrchestrationCleanupContractFixtures");
  for (const marker of [
    "postgres_deadlock_40P01", "observer_probe_late_success_rejected", "ms18_future_start_rejection_missing",
    "ms20_post_lock_authorization_rejected", "phase05_scenario_failure", "failing_cleanup_attempted",
    "later_cleanup_attempted", "successful_primary_cleanup_rejected", "orchestration_primary_error_record_fixture_rejected",
    "orchestration_failed_cleanup_false_removal_fixture_rejected", "orchestration_idempotent_ownership_fixture_rejected",
    "connection_cleanup_nonthrowing_fixture_rejected",
  ]) assert.ok(fixtures.includes(marker), `Falta fixture de orquestación: ${marker}`);
  assert.match(extractFunction(source, "Invoke-Phase00Validate"), /Assert-OrchestrationCleanupContractFixtures/);

  const clear = extractFunction(source, "Clear-ConnectionMaterial");
  assert.match(clear, /if \(\$null -eq \$Connection\) \{ return \}/);
  assert.match(clear, /foreach \(\$name in @\("Password", "User", "Host", "Database"\)\)/);
  assert.match(clear, /catch \{ \}/);
  for (const mode of ["Invoke-ReadOnlyProbeMode", "Invoke-PostcheckOnlyMode", "Invoke-ExecuteMode"]) {
    const block = extractFunction(source, mode);
    assert.match(block, /finally\s*\{\s*Clear-ConnectionMaterial -Connection \$connection\s*\}/);
    assert.doesNotMatch(block, /finally\s*\{[\s\S]*?(?:Stop-|Invoke-Psql|Remove-RuntimeActivityFixture)/);
  }
  for (const helper of ["New-CanonicalEnvironmentProcessStartInfo", "Assert-TerminalArtifactContractFixtures", "Invoke-CredentialStateCleanup", "Invoke-ExternalFileStateCleanup"]) {
    const block = extractFunction(source, helper);
    assert.doesNotMatch(block, /\bfinally\s*\{/);
    assert.match(block, /Invoke-OrchestrationCleanup/);
    if (helper !== "Invoke-CredentialStateCleanup" && helper !== "Invoke-ExternalFileStateCleanup") assert.match(block, /Complete-OrchestrationCleanup/);
  }
  const connectionInput = extractFunction(source, "ConvertFrom-HiddenConnectionInput");
  assert.doesNotMatch(connectionInput, /\bfinally\s*\{/);
  assert.match(connectionInput, /Invoke-CredentialStateCleanup/);
  assert.match(connectionInput, /Complete-OrchestrationCleanup/);
  const externalWrite = extractFunction(source, "Write-ExternalUtf8File");
  assert.doesNotMatch(externalWrite, /\bfinally\s*\{/);
  assert.match(externalWrite, /Invoke-ExclusiveExternalFileWrite/);
  const exclusiveWrite = extractFunction(source, "Invoke-ExclusiveExternalFileWrite");
  assert.doesNotMatch(exclusiveWrite, /\bfinally\s*\{/);
  assert.match(exclusiveWrite, /Invoke-ExternalFileStateCleanup/);
  assert.match(exclusiveWrite, /Complete-OrchestrationCleanup/);
  const diagnosticFixture = extractFunction(source, "Assert-DiagnosticContractFixtures");
  assert.match(diagnosticFixture, /finally\s*\{\s*Remove-Item[^\n]*-ErrorAction SilentlyContinue\s*\}/);
  const hash = extractFunction(source, "Get-TextSha256");
  assert.match(hash, /finally \{ \$algorithm\.Dispose\(\) \}/);
  let withoutClassifiedFinalizers = source;
  for (const name of ["Get-TextSha256", "Assert-DiagnosticContractFixtures", "Invoke-ReadOnlyProbeMode", "Invoke-PostcheckOnlyMode", "Invoke-ExecuteMode"]) {
    withoutClassifiedFinalizers = withoutClassifiedFinalizers.replace(extractFunction(withoutClassifiedFinalizers, name), "");
  }
  assert.doesNotMatch(withoutClassifiedFinalizers, /\bfinally\s*\{/, "Existe un finally no clasificado por DB-18");
};

const validateCleanupStatePropagationContract = (source) => {
  const secondary = extractFunction(source, "Invoke-SecondaryFailureOperation");
  assert.match(secondary, /propiedades de objetos compartidos sí se propagan/);
  assert.match(secondary, /asignaciones escalares quedan en el scope hijo/);
  assert.match(secondary, /consumir Operation\.Value/);
  assert.match(secondary, /Value = \(& \$Operation\)/);
  assert.doesNotMatch(secondary, /Value = \(\. \$Operation\)|Set-Variable\s+-Scope/);

  const credentialCleanup = extractFunction(source, "Invoke-CredentialStateCleanup");
  for (const field of ["CredentialState.Pointer", "CredentialState.PointerFreed", "CredentialState.PointerFreeCount", "CredentialState.Plain", "CredentialState.Secure", "CredentialState.TextReferencesCleared"]) {
    assert.ok(credentialCleanup.includes(`$${field}`), `Cleanup de credencial omite ${field}`);
  }
  requireInOrder(credentialCleanup, [
    "ZeroFreeBSTR($CredentialState.Pointer)",
    "$CredentialState.Pointer = [IntPtr]::Zero",
    "$CredentialState.PointerFreeCount++",
    "$CredentialState.PointerFreed = $true",
    "$CredentialState.Plain = $null",
    "$CredentialState.Secure = $null",
    "$CredentialState.TextReferencesCleared = $true",
  ], "La credencial debe borrar el BSTR exactamente antes de soltar referencias");
  assert.doesNotMatch(credentialCleanup, /\$(?:pointer|plain|secure)\s*=/i);

  const connection = extractFunction(source, "ConvertFrom-HiddenConnectionInput");
  assert.match(connection, /\$credentialState = \[pscustomobject\]@\{/);
  assert.match(connection, /Invoke-CredentialStateCleanup -CredentialState \$credentialState/);
  assert.match(connection, /database_connection_cleanup_postcondition_rejected/);
  for (const postcondition of ["$credentialState.Pointer -eq [IntPtr]::Zero", "$credentialState.PointerFreeCount -eq 1", "$null -eq $credentialState.Plain", "$null -eq $credentialState.Secure", "$credentialState.TextReferencesCleared"]) {
    assert.ok(connection.includes(postcondition), `Postcondición de credencial omite ${postcondition}`);
  }
  assert.doesNotMatch(connection, /\$(?:pointer|plain|secure)\s*=/i);

  const fileCleanup = extractFunction(source, "Invoke-ExternalFileStateCleanup");
  for (const field of ["FileState.WriterOwned", "FileState.Writer", "FileState.WriterDisposed", "FileState.StreamOwned", "FileState.Stream", "FileState.StreamDisposed"]) {
    assert.ok(fileCleanup.includes(`$${field}`), `Cleanup de archivo omite ${field}`);
  }
  requireInOrder(fileCleanup, ["EXTERNAL_WRITER_DISPOSE", "$FileState.Writer.Dispose()", "EXTERNAL_STREAM_DISPOSE", "$FileState.Stream.Dispose()"], "Writer y stream deben limpiarse de forma independiente");
  assert.doesNotMatch(fileCleanup, /\$(?:writer|stream)\s*=/i);

  const exclusive = extractFunction(source, "Invoke-ExclusiveExternalFileWrite");
  requireInOrder(exclusive, [
    "$fileState = [pscustomobject]@{",
    "$fileState.Stream = New-Object System.IO.FileStream",
    "$fileState.StreamOwned = $true",
    "$fileState.Writer = New-Object System.IO.StreamWriter",
    "$fileState.WriterOwned = $true",
    "$fileState.Writer.Write($Content)",
    "$fileState.Writer.Flush()",
    "Invoke-ExternalFileStateCleanup -FileState $fileState",
    "Complete-OrchestrationCleanup",
    "Test-Path -LiteralPath $FullPath -PathType Leaf",
    "external_file_cleanup_postcondition_rejected",
    "return $fileState",
  ], "La escritura exclusiva debe adquirir, vaciar, limpiar y probar sus recursos");
  const write = extractFunction(source, "Write-ExternalUtf8File");
  requireInOrder(write, ["external_file_path_rejected", "if ($Exclusive)", "Invoke-ExclusiveExternalFileWrite"], "La ruta debe validarse antes de abrir el archivo exclusivo");
  assert.doesNotMatch(write, /\$(?:writer|stream)\s*=/i);

  const fixtures = extractFunction(source, "Assert-CleanupStatePropagationFixtures");
  for (const marker of [
    "child_scope_scalar_propagation_fixture_rejected", "child_scope_object_property_fixture_rejected",
    "child_scope_return_consumption_fixture_rejected", "credential_state_cleanup_fixture_rejected",
    "credential_primary_error_identity_fixture_rejected", "credential_success_cleanup_failure_fixture_rejected",
    "exclusive_file_content_fixture_rejected", "new_sql_file_cleanup_fixture_rejected",
    "writer_construction_primary_preservation_fixture_rejected", "writer_disposal_independent_stream_cleanup_fixture_rejected",
    "file_success_cleanup_failure_fixture_rejected", "writer_disposal_primary_error_identity_fixture_rejected",
    "6f324fdefad92627e6bc93a44752e4c533241c30ad1d14d0e72de2f7ecf82589",
  ]) assert.ok(fixtures.includes(marker), `Fixture DB-19 ausente: ${marker}`);
  requireInOrder(fixtures, ["$returnedScalar = Invoke-SecondaryFailureOperation", "$returnedScalar.Succeeded", "$returnedScalar.Value"], "El valor escalar retornado debe consumirse en el scope caller");
  assert.match(extractFunction(source, "Invoke-Phase00Validate"), /Assert-CleanupStatePropagationFixtures/);
  assert.doesNotMatch(`${credentialCleanup}\n${connection}\n${fileCleanup}\n${exclusive}\n${write}`, /\$(?:global|script):(?:Credential|File|Pointer|Plain|Secure|Writer|Stream)|Set-Variable\s+-Scope|^\s*\.\s+\$Operation/m);
};

const validateStagedStartOwnershipContract = (source) => {
  const cleanup = extractFunction(source, "Invoke-StagedProcessStartFailureCleanup");
  requireInOrder(cleanup, [
    "$cleanupProcess =", "$cleanupProcessStarted =", "$cleanupStartInfo =", "START_INFO_CLEAR", "FALLBACK_ESCROW", "INPUT_CLOSE", "PROCESS_TERMINATE", "$cleanupProcess.Kill()", "$cleanupProcess.WaitForExit(5000)",
    "Assert-Condition -Condition $cleanupProcess.HasExited", "$State.ProcessTerminationObserved = $true",
    "LOCAL_PID_REMOVE", "$State.LocalPidRemovalAttempted = $true", "$State.ProcessTerminationObserved", "Update-WorkerPidManifest",
    "EXECUTE_PID_REMOVE", "$State.ExecutePidRemovalAttempted = $true", "$State.ProcessTerminationObserved", "Update-ExecuteWorkerManifest",
  ], "El cleanup de arranque debe observar terminación antes de retirar ambas fuentes PID");
  assert.match(cleanup, /Invoke-OrchestrationCleanup -EmitFailureMarkers -CleanupOperations/);
  assert.match(cleanup, /if \(\$State\.LocalPidAddAttempted\)/);
  assert.match(cleanup, /if \(\$State\.ExecutePidAddAttempted\)/);

  for (const name of ["Start-StagedInstallationHolder", "Start-StagedAuthorityLossHolder", "Start-PersistentInstallationObserver"]) {
    const start = extractFunction(source, name);
    for (const declaration of ["$process = $null", "$processStarted = $false", "$worker = $null", "$localPidRecorded = $false", "$executePidRecorded = $false", "$primaryError = $null", "$ownershipState = [pscustomobject]@{"]) {
      assert.ok(start.includes(declaration), `${name} omite estado de ownership ${declaration}`);
    }
    const tryIndex = start.indexOf("  try {");
    const processStartIndex = start.indexOf("$process.Start()", tryIndex);
    const escrowProcessIndex = start.indexOf("$ownershipState.Process = $process", processStartIndex);
    const escrowStartedIndex = start.indexOf("$ownershipState.ProcessStarted = $true", escrowProcessIndex);
    const clearIndex = start.indexOf("Clear-PsqlStartInfoMaterial -State $ownershipState -StartInfo $startInfo", escrowStartedIndex);
    const stdoutIndex = start.indexOf("$process.StandardOutput.ReadLineAsync()", clearIndex);
    const workerIndex = start.indexOf("$worker = [pscustomobject]@{", stdoutIndex);
    const localAddIndex = start.indexOf('Update-WorkerPidManifest -RunDirectory $RunDirectory', clearIndex);
    const executeAddIndex = start.indexOf('Update-ExecuteWorkerManifest -ExecutionContext $executionContext', localAddIndex);
    const returnIndex = start.indexOf("return $worker", executeAddIndex);
    const catchIndex = start.indexOf("\n  catch {", returnIndex);
    assert.ok(tryIndex >= 0 && tryIndex < processStartIndex && processStartIndex < escrowProcessIndex && escrowProcessIndex < escrowStartedIndex && escrowStartedIndex < clearIndex && clearIndex < stdoutIndex && stdoutIndex < workerIndex && workerIndex < localAddIndex && localAddIndex < executeAddIndex && executeAddIndex < returnIndex && returnIndex < catchIndex, `${name} deja setup fuera del ownership try`);
    assert.doesNotMatch(start.slice(0, tryIndex), /\$process\.Start\(\)|ReadLineAsync\(\)|Clear-PsqlStartInfoMaterial|\$worker = \[pscustomobject\]@\{|Update-(?:WorkerPidManifest|ExecuteWorkerManifest)/, `${name} ejecuta setup throwable antes del ownership try`);
    for (const precomputed of ["$stdoutLines = New-Object System.Collections.ArrayList", "$stderrLines = New-Object System.Collections.ArrayList", "$executionContext = if", "$startInfo = New-StagedPsqlStartInfo"]) {
      assert.ok(start.indexOf(precomputed) >= 0 && start.indexOf(precomputed) < tryIndex, `${name} no precalcula ${precomputed}`);
    }
    assert.match(start, /catch \{\n    \$primaryError = \$_\n    \$ownershipState\.PrimaryErrorRecord = \$_/);
    requireInOrder(start.slice(catchIndex), ["$primaryError = $_", "Invoke-StagedProcessStartFailureCleanup", "$ownershipState.RethrowErrorRecord = $primaryError", "throw $primaryError"], `${name} debe congelar y relanzar el ErrorRecord original`);
    assert.match(start.slice(catchIndex), /-FallbackProcess \$process -FallbackProcessStarted \$processStarted -FallbackStartInfo \$startInfo/);
    assert.equal(occurrences(start, /return \$worker/g), 1, `${name} sólo puede retornar un worker completo`);
    assert.doesNotMatch(start.slice(catchIndex), /Update-(?:WorkerPidManifest|ExecuteWorkerManifest)[^\n]*-Operation "remove"/, `${name} no puede retirar PID directamente en catch`);
    assert.match(start, /\$ownershipState\.LocalPidAddAttempted = \$true[\s\S]*Update-WorkerPidManifest[\s\S]*\$ownershipState\.LocalPidRecorded = \$true/);
    assert.match(start, /\$ownershipState\.ExecutePidAddAttempted = \$true[\s\S]*Update-ExecuteWorkerManifest[\s\S]*\$ownershipState\.ExecutePidRecorded = \$true/);
  }

  const model = extractFunction(source, "Invoke-SyntheticStagedStartOwnershipModel");
  assert.doesNotMatch(model, /ProcessStartInfo|\.Start\(\)|Read-Host|Invoke-Psql|pg_dump/);
  for (const point of ["before_start", "after_start", "stdout_task", "worker_construction", "start_info_clear", "execute_pid_add", "success"]) assert.ok(model.includes(`"${point}"`));
  const fixtures = extractFunction(source, "Assert-StagedStartOwnershipFixtures");
  for (const pattern of ["Start-StagedInstallationHolder", "Start-StagedAuthorityLossHolder", "Start-PersistentInstallationObserver"]) assert.ok(fixtures.includes(`"${pattern}"`));
  for (const marker of [
    "staged_start_primary_error_identity_fixture_rejected", "staged_start_pre_start_ownership_fixture_rejected",
    "staged_start_post_start_termination_fixture_rejected", "staged_start_partial_worker_return_fixture_rejected",
    "staged_start_second_pid_failure_cleanup_fixture_rejected", "staged_start_local_removal_independence_fixture_rejected",
    "staged_start_execute_removal_primary_preservation_fixture_rejected", "staged_start_complete_worker_fixture_rejected",
  ]) assert.ok(fixtures.includes(marker), `Fixture de ownership DB-19 ausente: ${marker}`);
  assert.match(fixtures, /ReferenceEquals\(\$state\.PrimaryErrorRecord, \$state\.RethrowErrorRecord\)/);
  assert.match(extractFunction(source, "Invoke-Phase00Validate"), /Assert-StagedStartOwnershipFixtures/);
};

const validateLocalModes = (source) => {
  const validate = `${extractFunction(source, "Invoke-ValidateOnlyMode")}\n${extractFunction(source, "Invoke-Phase00Validate")}`;
  assert.doesNotMatch(validate, /ConvertFrom-HiddenConnectionInput|Read-Host|Invoke-Psql|Start-PsqlWorker|Wait-PsqlWorker|ProcessStartInfo|\.Start\(\)|pg_dump/);
  assert.match(validate, /REMOTE_CONNECTION\|NOT_ATTEMPTED/);
  assert.match(validate, /DATABASE_CREDENTIAL_PROMPT\|NOT_ATTEMPTED/);
  assert.match(validate, /MULTISESSION_EXECUTION\|NOT_ATTEMPTED/);
  for (const fixture of ["Assert-PgOptionsContractFixtures", "Assert-GenericObserverContractFixtures", "Assert-RuntimeObservationContractFixtures", "Assert-InstallationLockBudgetFixtures", "Assert-StagedWorkerContractFixtures", "Assert-InstallationObserverContractFixtures", "Assert-SameProcessIsolationMarkerFixtures", "Assert-WallClockTimingContract", "Assert-TerminalArtifactContractFixtures", "Assert-SecondaryFailurePreservationFixtures", "Assert-OrchestrationCleanupContractFixtures", "Assert-CleanupStatePropagationFixtures", "Assert-StagedStartOwnershipFixtures", "Assert-FailureScenarioContractFixtures", "Assert-Db25VerifiedArtifactAndProcessEscrowFixtures", "Assert-Db26WorkerHandoffAndMarkerDeadlineFixtures", "Assert-Db27RollbackRelationHolderFixtures"]) assert.match(validate, new RegExp(fixture));
  const probe = extractFunction(source, "Invoke-ReadOnlyProbeMode");
  assert.doesNotMatch(probe, /Invoke-ExactRepositorySqlFile|Invoke-Phase0[2-6]/);
  const baseline = extractFunction(source, "Get-BaselineProbeSql");
  assert.match(baseline, /set transaction read only;/i);
  assert.match(baseline, /rollback;/i);
};

const validateNoEmbeddedCredential = (source) => {
  let sanitized = source;
  for (const name of ["Assert-SanitizerContract", "Assert-TargetBoundaryContract"]) sanitized = sanitized.replace(extractFunction(sanitized, name), "");
  assert.doesNotMatch(sanitized, /postgres(?:ql)?:\/\/\S+/i);
  assert.doesNotMatch(sanitized, /https?:\/\/\S+/i);
  assert.doesNotMatch(sanitized, /(?:password|bearer)[=:]\s*["'][^"']+["']/i);
  assert.doesNotMatch(sanitized, /[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}/i);
};

const validateNoDestructiveBypass = (source) => {
  assert.doesNotMatch(source, /\bsession_replication_role\b|\bdisable\s+trigger\b|\bdrop\s+trigger\b/i);
  assert.doesNotMatch(source, /^\s*truncate\s+(?:table\s+)?/im);
  assert.doesNotMatch(source, /\bsupabase\s+(?:db|functions)\b|\bauth\s+admin\b/i);
};

const validatePhaseOrder = (source) => {
  const execute = extractFunction(source, "Invoke-ExecuteMode");
  requireInOrder(execute, ["Invoke-Phase02InstallationMatrix", "Invoke-Phase03RollbackMatrix", "Invoke-Phase04Reapply0011", "Invoke-Phase05RuntimeMatrix", "Invoke-Phase06FinalPostcheck"], "Orden de fases");
  requireInOrder(migration.toLowerCase(), ["lock table public.activities in share row exclusive mode", "lock table public.academic_periods in access exclusive mode"], "Orden estructural");
};

const validatePowerShellBalance = (source) => {
  let inHere = null;
  const sanitized = [];
  for (const line of source.split("\n")) {
    const trimmed = line.trim();
    if (inHere) {
      if (trimmed.startsWith(`${inHere}@`)) { sanitized.push(trimmed.slice(2)); inHere = null; } else sanitized.push("");
      continue;
    }
    if (trimmed.endsWith('@"')) { inHere = '"'; sanitized.push(line.slice(0, line.lastIndexOf('@"'))); continue; }
    if (trimmed.endsWith("@'")) { inHere = "'"; sanitized.push(line.slice(0, line.lastIndexOf("@'"))); continue; }
    sanitized.push(line.replace(/'(?:''|[^'])*'/g, "''").replace(/"(?:`.|[^"`])*"/g, '""'));
  }
  assert.equal(inHere, null, "Here-string sin cerrar");
  const text = sanitized.join("\n");
  for (const [open, close] of [["{", "}"], ["(", ")"], ["[", "]"]]) {
    assert.equal(occurrences(text, new RegExp(`\\${open}`, "g")), occurrences(text, new RegExp(`\\${close}`, "g")), `Desbalance ${open}${close}`);
  }
};

const scenarioBlock = extractMarkedBlock(harness, "# BEGIN REQUIRED_SCENARIOS", "# END REQUIRED_SCENARIOS");
const scenarioIds = validateScenarioMap(scenarioBlock);
validateWorkerSourceLifecycle(harness);
validatePsqlProcessTimeoutContract(harness);
validateDb25VerifiedIdentityAndEscrowContract(harness);
validateDb26WorkerHandoffAndMarkerDeadlineContract(harness);
validateExplicitApprovals(harness, scenarioIds);
validateManifestStateMachine(harness);
validatePostcheckDiagnostic(harness);
validatePhaseBoundaryContract(harness);
validateInstallation(harness);
validateRollback(harness);
validateInstallationTimingContract(harness, migration);
validatePersistentInstallationObserver(harness);
validateStagedInstallationHolder(harness);
validateSameProcessIsolationMarker(harness);
validatePgOptionsContract(harness);
validateWallClockTimingContract(harness);
validateGenericObserverContract(harness);
validateAdvisoryPairContract(harness);
validateAdvisoryHolderReadinessContract(harness);
validateExactSem01AdvisoryIdentity(harness);
validateAdvisoryResidueContract(harness);
validateStagedRuntimeHolderContract(harness);
validatePairedSqlLifecycleContract(harness);
validateTransientSqlCreationContract(harness);
validateAuthorityLossContract(harness);
validateMs20CandidateSetContract(harness);
validateRuntimeSemantics(harness);
validateTerminalArtifactContract(harness);
validateFingerprint(harness);
validateRoutineAclExactFixtures(harness);
validateTargetBoundary(harness, canonicalBoundary);
validateFailures(harness);
validateOrchestrationCleanupContract(harness);
validateCleanupStatePropagationContract(harness);
validateStagedStartOwnershipContract(harness);
validateLocalModes(harness);
validateNoEmbeddedCredential(harness);
validateNoDestructiveBypass(harness);
validatePhaseOrder(harness);
validatePowerShellBalance(harness);

const mutateFingerprintSql = (transform) => {
  const block = extractFunction(harness, "Get-BaselineProbeSql");
  return harness.replace(block, transform(block));
};
const mutatePostcheck = (transform) => {
  const block = extractFunction(harness, "Invoke-PostcheckOnlyMode");
  return harness.replace(block, transform(block));
};
const mutateRenderer = (transform) => {
  const block = extractFunction(harness, "Get-PostcheckDiagnosticLines");
  return harness.replace(block, transform(block));
};
const mutateHarnessFunction = (name, transform) => {
  const block = extractFunction(harness, name);
  return harness.replace(block, transform(block));
};
const appendThrowableFinally = (name, statement) => mutateHarnessFunction(name, (block) => block.replace(/\n}\s*$/, `\n  finally { ${statement} }\n}`));

expectReject("finally detiene Psql directamente", () => validateOrchestrationCleanupContract(appendThrowableFinally("Invoke-Phase03RollbackMatrix", "Stop-PsqlWorker -Worker $holder")));
expectReject("finally detiene holder staged directamente", () => validateOrchestrationCleanupContract(appendThrowableFinally("Invoke-Phase02InstallationMatrix", "Stop-StagedInstallationHolder -Worker $holder")));
expectReject("finally detiene observer persistente directamente", () => validateOrchestrationCleanupContract(appendThrowableFinally("Invoke-Phase02InstallationMatrix", "Stop-PersistentInstallationObserver -Observer $observer")));
expectReject("finally ejecuta cleanup SQL directamente", () => validateOrchestrationCleanupContract(appendThrowableFinally("Invoke-Phase05RuntimeMatrix", "Invoke-PsqlSql -Connection $Connection -PsqlPath $PsqlPath -Sql $existsSql")));
expectReject("finally elimina fixture remota directamente", () => validateOrchestrationCleanupContract(appendThrowableFinally("Invoke-WallClockScenarios", "Remove-RuntimeActivityFixture -Connection $Connection -ActivityId $activityId")));
expectReject("cleanup reemplaza ErrorRecord primario de orquestación", () => validateOrchestrationCleanupContract(mutateHarnessFunction("Complete-OrchestrationCleanup", (block) => block.replace("throw $PrimaryError", 'throw "secondary_cleanup_failure"'))));
expectReject("sólo se intenta el primer cleanup tras fallar", () => validateOrchestrationCleanupContract(mutateHarnessFunction("Invoke-OrchestrationCleanup", (block) => block.replace("foreach ($cleanupOperation in @($CleanupOperations))", "foreach ($cleanupOperation in @($CleanupOperations | Select-Object -First 1))"))));
expectReject("PHASE_05 continúa a MS21 antes de validar cleanup", () => validateOrchestrationCleanupContract(mutateHarnessFunction("Invoke-Phase05RuntimeMatrix", (block) => {
  const marker = '  Set-CurrentScenario -ScenarioId "MS21_ADVISORY_OBSERVATION"';
  return block.replace(`${marker}\n`, "").replace("  Complete-OrchestrationCleanup", `${marker}\n  Complete-OrchestrationCleanup`);
})));
expectReject("wall-clock aprueba antes de remover fixture", () => validateOrchestrationCleanupContract(mutateHarnessFunction("Invoke-WallClockScenarios", (block) => {
  const approval = "    Approve-ScenarioResult -ApprovedResults $ApprovedResults -Manifest $Manifest -Paths $Paths -Result $scenarioResult";
  return block.replace(`${approval}\n`, "").replace("    $wallCleanup = Invoke-OrchestrationCleanup", `${approval}\n    $wallCleanup = Invoke-OrchestrationCleanup`);
})));
expectReject("cleanup cambia FailureScenario", () => validateOrchestrationCleanupContract(mutateHarnessFunction("Complete-OrchestrationCleanup", (block) => block.replace("$script:CurrentScenario = $PrimaryScenario", '$script:CurrentScenario = "MS24_ZERO_RESIDUE"'))));
expectReject("cleanup cambia FailureClass", () => validateOrchestrationCleanupContract(mutateHarnessFunction("Complete-OrchestrationCleanup", (block) => block.replace("throw $PrimaryError", 'Throw-StableFailure -Code $PrimaryError.Exception.Message -FailureClass "source_integrity_rejection"'))));
expectReject("ruta primaria exitosa suprime fallo de cleanup", () => validateOrchestrationCleanupContract(mutateHarnessFunction("Complete-OrchestrationCleanup", (block) => block.replace('-FailureClass "postcondition_rejection"', '-FailureClass "source_integrity_rejection"'))));

expectReject("cleanup de credencial reasigna pointer escalar en scope hijo", () => validateCleanupStatePropagationContract(mutateHarnessFunction("Invoke-CredentialStateCleanup", (block) => block.replace("$CredentialState.Pointer = [IntPtr]::Zero", "$pointer = [IntPtr]::Zero"))));
expectReject("postcondición de credencial depende de pointer escalar", () => validateCleanupStatePropagationContract(mutateHarnessFunction("ConvertFrom-HiddenConnectionInput", (block) => block.replace("$credentialState.Pointer -eq [IntPtr]::Zero", "$pointer -eq [IntPtr]::Zero"))));
expectReject("cleanup de archivo reasigna writer escalar en scope hijo", () => validateCleanupStatePropagationContract(mutateHarnessFunction("Invoke-ExternalFileStateCleanup", (block) => block.replace("$FileState.Writer = $null", "$writer = $null"))));
expectReject("cleanup de archivo reasigna stream escalar en scope hijo", () => validateCleanupStatePropagationContract(mutateHarnessFunction("Invoke-ExternalFileStateCleanup", (block) => block.replace("$FileState.Stream = $null", "$stream = $null"))));
expectReject("se elimina la postcondición de cleanup de conexión", () => validateCleanupStatePropagationContract(mutateHarnessFunction("ConvertFrom-HiddenConnectionInput", (block) => block.replace("database_connection_cleanup_postcondition_rejected", "database_connection_cleanup_postcondition_omitted"))));
expectReject("se elimina la postcondición de cleanup de archivo", () => validateCleanupStatePropagationContract(mutateHarnessFunction("Invoke-ExclusiveExternalFileWrite", (block) => block.replace("external_file_cleanup_postcondition_rejected", "external_file_cleanup_postcondition_omitted"))));
expectReject("cleanup comunica estado mediante variable global", () => validateCleanupStatePropagationContract(mutateHarnessFunction("Invoke-CredentialStateCleanup", (block) => block.replace("  return Invoke-OrchestrationCleanup", "  $script:CredentialState = $CredentialState\n  return Invoke-OrchestrationCleanup"))));
expectReject("cleanup usa Set-Variable con scope padre", () => validateCleanupStatePropagationContract(mutateHarnessFunction("Invoke-CredentialStateCleanup", (block) => block.replace("  return Invoke-OrchestrationCleanup", "  Set-Variable -Scope 1 -Name pointer -Value ([IntPtr]::Zero)\n  return Invoke-OrchestrationCleanup"))));
expectReject("cleanup se dota para mutar scope caller", () => validateCleanupStatePropagationContract(mutateHarnessFunction("Invoke-SecondaryFailureOperation", (block) => block.replace("Value = (& $Operation)", "Value = (. $Operation)"))));
expectReject("valor escalar retornado por cleanup no se consume", () => validateCleanupStatePropagationContract(mutateHarnessFunction("Assert-CleanupStatePropagationFixtures", (block) => block.replace("$returnedScalar.Value", '"returned"'))));

expectReject("Process.Start precede al ownership try con ReadLineAsync", () => validateStagedStartOwnershipContract(mutateHarnessFunction("Start-StagedInstallationHolder", (block) => block.replace("  try {", "  [void]$process.Start()\n  [void]$process.StandardOutput.ReadLineAsync()\n  try {"))));
expectReject("Process.Start precede al ownership try con limpieza de StartInfo", () => validateStagedStartOwnershipContract(mutateHarnessFunction("Start-StagedAuthorityLossHolder", (block) => block.replace("  try {", "  [void]$process.Start()\n  Clear-ChildPgEnvironment -StartInfo $startInfo\n  try {"))));
expectReject("Process.Start precede al ownership try con worker parcial", () => validateStagedStartOwnershipContract(mutateHarnessFunction("Start-PersistentInstallationObserver", (block) => block.replace("  try {", "  [void]$process.Start()\n  $worker = [pscustomobject]@{ Process = $process }\n  try {"))));
expectReject("segundo alta PID falla sin cleanup completo", () => validateStagedStartOwnershipContract(mutateHarnessFunction("Invoke-StagedProcessStartFailureCleanup", (block) => block.replace("EXECUTE_PID_REMOVE", "EXECUTE_PID_REMOVE_OMITTED"))));
expectReject("catch retira PID local sin protección y puede reemplazar el primario", () => validateStagedStartOwnershipContract(mutateHarnessFunction("Start-StagedInstallationHolder", (block) => block.replace("    throw $primaryError", '    Update-WorkerPidManifest -RunDirectory $RunDirectory -ProcessId $process.Id -ApplicationName $applicationName -Operation "remove"\n    throw $primaryError'))));
expectReject("cleanup retira sólo una fuente PID", () => validateStagedStartOwnershipContract(mutateHarnessFunction("Invoke-StagedProcessStartFailureCleanup", (block) => block.replace("Update-ExecuteWorkerManifest -ExecutionContext", "Omitted-ExecuteWorkerManifest -ExecutionContext"))));
expectReject("starter retorna worker antes de sincronizar PID Execute", () => validateStagedStartOwnershipContract(mutateHarnessFunction("Start-StagedAuthorityLossHolder", (block) => block.replace("      Update-ExecuteWorkerManifest -ExecutionContext", "      return $worker\n      Update-ExecuteWorkerManifest -ExecutionContext"))));
expectReject("cleanup retira PID sin observar terminación", () => validateStagedStartOwnershipContract(mutateHarnessFunction("Invoke-StagedProcessStartFailureCleanup", (block) => block.replace("$State.ProcessTerminationObserved = $true", "$State.ProcessTerminationNotObserved = $true"))));

expectReject("eliminación incondicional histórica", () => validateWorkerSourceLifecycle(harness.replace(extractFunction(harness, "Wait-PsqlWorker"), 'function Wait-PsqlWorker { Remove-Item -LiteralPath $Worker.SqlFile }')));
expectReject("flag destructivo por defecto", () => validateWorkerSourceLifecycle(harness.replace("[bool]$DeleteSqlFileOnCompletion = $false", "[bool]$DeleteSqlFileOnCompletion = $true")));
expectReject("SQL de repositorio borrable", () => validateWorkerSourceLifecycle(harness.replaceAll("-DeleteSqlFileOnCompletion $false", "-DeleteSqlFileOnCompletion $true")));
expectReject("DB-16 lee ProcessTimeoutMilliseconds sin declararlo en Invoke-PsqlFile", () => validatePsqlProcessTimeoutContract(mutateHarnessFunction("Invoke-PsqlFile", (block) => block.replace('    [ValidateRange(0, 600000)][int]$ProcessTimeoutMilliseconds = 0,\n', ""))));
expectReject("Invoke-PsqlSql pasa un parámetro nombrado ausente en Invoke-PsqlFile", () => validatePsqlProcessTimeoutContract(mutateHarnessFunction("Invoke-PsqlFile", (block) => block.replace('    [ValidateRange(0, 600000)][int]$ProcessTimeoutMilliseconds = 0,\n', ""))));
expectReject("timeout declarado únicamente en Start-PsqlWorker", () => {
  const withoutFileParameter = mutateHarnessFunction("Invoke-PsqlFile", (block) => block.replace('    [ValidateRange(0, 600000)][int]$ProcessTimeoutMilliseconds = 0,\n', ""));
  const startBlock = extractFunction(withoutFileParameter, "Start-PsqlWorker");
  validatePsqlProcessTimeoutContract(withoutFileParameter.replace(startBlock, startBlock.replace("    [int]$LockTimeoutMilliseconds = 30000,", "    [int]$LockTimeoutMilliseconds = 30000,\n    [int]$ProcessTimeoutMilliseconds = 0,")));
});
expectReject("Invoke-PsqlFile depende de scope dinámico", () => validatePsqlProcessTimeoutContract(mutateHarnessFunction("Invoke-PsqlFile", (block) => block.replace('    [ValidateRange(0, 600000)][int]$ProcessTimeoutMilliseconds = 0,\n', ""))));
expectReject("Start-PsqlWorker precede la resolución del timeout", () => validatePsqlProcessTimeoutContract(mutateHarnessFunction("Invoke-PsqlFile", (block) => {
  const lines = block.split("\n");
  const resolveIndex = lines.findIndex((line) => line.includes("$effectiveProcessTimeout = Resolve-PsqlProcessTimeoutMilliseconds"));
  const startIndex = lines.findIndex((line) => line.includes("$worker = Start-PsqlWorker"));
  [lines[resolveIndex], lines[startIndex]] = [lines[startIndex], lines[resolveIndex]];
  return lines.join("\n");
})));
expectReject("Wait usa StatementTimeoutMilliseconds", () => validatePsqlProcessTimeoutContract(mutateHarnessFunction("Invoke-PsqlFile", (block) => block.replace("-TimeoutMilliseconds $effectiveProcessTimeout", "-TimeoutMilliseconds $StatementTimeoutMilliseconds"))));
expectReject("Wait usa LockTimeoutMilliseconds", () => validatePsqlProcessTimeoutContract(mutateHarnessFunction("Invoke-PsqlFile", (block) => block.replace("-TimeoutMilliseconds $effectiveProcessTimeout", "-TimeoutMilliseconds $LockTimeoutMilliseconds"))));
expectReject("wrapper protegido sin timeout de proceso determinista", () => validatePsqlProcessTimeoutContract(mutateHarnessFunction("Invoke-ExactRepositorySqlFile", (block) => block.replace(" -ProcessTimeoutMilliseconds $script:RepositorySqlProcessTimeoutMilliseconds", ""))));
expectReject("cleanup reemplaza el ErrorRecord primario", () => validatePsqlProcessTimeoutContract(mutateHarnessFunction("Invoke-PsqlFile", (block) => block.replace("Complete-OrchestrationCleanup -PrimaryError $primaryError", "Complete-OrchestrationCleanup -PrimaryError $null"))));
expectReject("cleanup omite retirar el worker de manifiestos", () => validatePsqlProcessTimeoutContract(mutateHarnessFunction("Invoke-PsqlFile", (block) => block.replace("Stop-PsqlWorker -Worker $worker", "OmittedStopPsqlWorker -Worker $worker"))));
expectReject("SQL protegido se vuelve borrable en el controlador", () => validatePsqlProcessTimeoutContract(mutateHarnessFunction("Invoke-ExactRepositorySqlFileResult", (block) => block.replace("-DeleteSqlFileOnCompletion $false", "-DeleteSqlFileOnCompletion $true"))));
expectReject("observer pierde timeout acotado de proceso", () => validatePsqlProcessTimeoutContract(mutateHarnessFunction("Invoke-AdvisoryPairObservationProbe", (block) => block.replace(" -ProcessTimeoutMilliseconds $script:ObserverProbeProcessTimeoutMilliseconds", ""))));
expectReject("timeout se resuelve antes del ownership controller", () => validatePsqlProcessTimeoutContract(mutateHarnessFunction("Invoke-PsqlFile", (block) => {
  const lines = block.split("\n");
  const ownershipIndex = lines.findIndex((line) => line.includes("Set-PsqlDisposableControllerOwnership -State $ownershipState"));
  const resolveIndex = lines.findIndex((line) => line.includes("$effectiveProcessTimeout = Resolve-PsqlProcessTimeoutMilliseconds"));
  [lines[ownershipIndex], lines[resolveIndex]] = [lines[resolveIndex], lines[ownershipIndex]];
  return lines.join("\n");
})));
expectReject("timeout se resuelve antes de congelar path y RunDirectory", () => validatePsqlProcessTimeoutContract(mutateHarnessFunction("Invoke-PsqlFile", (block) => {
  const ownershipStart = block.indexOf("  $ownershipState =");
  const ownershipEnd = block.indexOf("  try {", ownershipStart);
  const ownershipBlock = block.slice(ownershipStart, ownershipEnd);
  return block.slice(0, ownershipStart) + block.slice(ownershipEnd).replace("    $effectiveProcessTimeout = Resolve-PsqlProcessTimeoutMilliseconds", `    $effectiveProcessTimeout = Resolve-PsqlProcessTimeoutMilliseconds\n${ownershipBlock.trimEnd()}`);
})));
expectReject("ownership controller se adquiere después de resolver timeout", () => validatePsqlProcessTimeoutContract(mutateHarnessFunction("Invoke-PsqlFile", (block) => block.replace(
  "        Set-PsqlDisposableControllerOwnership -State $ownershipState -SqlFile $SqlFile -RunDirectory $RunDirectory",
  "        Acquire-PsqlDisposableControllerOwnershipTooLate -State $ownershipState -SqlFile $SqlFile -RunDirectory $RunDirectory",
).replace(
  "    $effectiveProcessTimeout = Resolve-PsqlProcessTimeoutMilliseconds -StatementTimeoutMilliseconds $StatementTimeoutMilliseconds -ProcessTimeoutMilliseconds $ProcessTimeoutMilliseconds",
  "    $effectiveProcessTimeout = Resolve-PsqlProcessTimeoutMilliseconds -StatementTimeoutMilliseconds $StatementTimeoutMilliseconds -ProcessTimeoutMilliseconds $ProcessTimeoutMilliseconds\n    Set-PsqlDisposableControllerOwnership -State $ownershipState -SqlFile $SqlFile -RunDirectory $RunDirectory",
))));
expectReject("cleanup vuelve a depender de sqlLifecycleValidated", () => validatePsqlProcessTimeoutContract(mutateHarnessFunction("Invoke-PsqlFile", (block) => block.replace(
  '[string]$ownershipState.OwnerState -cin @("caller", "controller")',
  "$sqlLifecycleValidated",
))));
expectReject("catch omite cleanup disposable sin worker", () => validatePsqlProcessTimeoutContract(mutateHarnessFunction("Invoke-PsqlFile", (block) => block.replace(
  "$cleanup = Invoke-PsqlDisposableControllerCleanup -State $ownershipState",
  "$cleanup = [pscustomobject]@{ Succeeded = $true; SecondaryErrors = @() }",
))));
expectReject("Invoke-PsqlSql omite cleanup del handoff", () => validatePsqlProcessTimeoutContract(mutateHarnessFunction("Invoke-PsqlSql", (block) => block.replace(
  "Invoke-PsqlSqlOuterHandoffCleanup -State $handoffState",
  "[pscustomobject]@{ Succeeded = $true; SecondaryErrors = @() }",
))));
expectReject("handoff externo no es idempotente", () => validatePsqlProcessTimeoutContract(mutateHarnessFunction("Invoke-PsqlSql", (block) => block.replace(
  "Invoke-PsqlSqlOuterHandoffCleanup -State $handoffState",
  "Invoke-PsqlDisposableControllerCleanup -State $handoffState",
))));
expectReject("cleanup omite postcondición de ausencia", () => validatePsqlProcessTimeoutContract(mutateHarnessFunction("Invoke-PsqlDisposableOwnershipCleanup", (block) => block.replace(
  'psql_disposable_cleanup_absence_rejected',
  'psql_disposable_cleanup_absence_omitted',
))));
expectReject("SQL protegido se elimina tras rechazo de timeout", () => validatePsqlProcessTimeoutContract(mutateHarnessFunction("Invoke-PsqlFile", (block) => block.replace(
  "$cleanup = [pscustomobject]@{ Succeeded = $true; SecondaryErrors = @() }",
  "$cleanup = Invoke-PsqlDisposableControllerCleanup -State $ownershipState",
))));
expectReject("ownership se transfiere antes de completar Start-PsqlWorker", () => validatePsqlProcessTimeoutContract(mutateHarnessFunction("Start-PsqlWorker", (block) => block.replace(
  "    $worker = [pscustomobject]@{",
  "    Set-PsqlDisposableWorkerOwnership -State $startState -Worker $worker\n    $worker = [pscustomobject]@{",
).replace("      Set-PsqlDisposableWorkerOwnership -State $startState -Worker $worker", "      Omitted-PsqlDisposableWorkerOwnership -State $startState -Worker $worker"))));
expectReject("controller y worker reclaman ownership simultáneo", () => validatePsqlProcessTimeoutContract(mutateHarnessFunction("Set-PsqlDisposableWorkerOwnership", (block) => block.replace('$State.OwnerState = "worker"', '$State.OwnerState = "worker"\n  $State.OwnerState = "controller"'))));
expectReject("ningún actor conserva ownership antes del timeout", () => validatePsqlProcessTimeoutContract(mutateHarnessFunction("Set-PsqlDisposableControllerOwnership", (block) => block.replace('$State.OwnerState = "controller"', '$State.OwnerState = "none"'))));
expectReject("fixture DB-23 nunca crea SQL físico", () => validatePsqlProcessTimeoutContract(mutateHarnessFunction("Assert-Db23PsqlHandoffFixtures", (block) => block.replaceAll("New-SqlFile", "New-SyntheticSqlObject"))));
expectReject("fixture DB-23 inicia ProcessStartInfo", () => validatePsqlProcessTimeoutContract(mutateHarnessFunction("Assert-Db23PsqlHandoffFixtures", (block) => block.replace("  try {", "  $forbidden = [System.Diagnostics.ProcessStartInfo]::new()\n  try {"))));
expectReject("orden residual DB-22 deja sobrevivir el SQL tras overflow", () => validatePsqlProcessTimeoutContract(mutateHarnessFunction("Invoke-PsqlFile", (block) => {
  const lines = block.replace(
    "$workerCollected = $false",
    "$workerCollected = $false\n  $sqlLifecycleValidated = $false",
  ).replace(
    "    Assert-Condition -Condition (Test-Path -LiteralPath $SqlFile -PathType Leaf) -Code \"worker_sql_file_missing\"",
    "    Assert-Condition -Condition (Test-Path -LiteralPath $SqlFile -PathType Leaf) -Code \"worker_sql_file_missing\"\n    $sqlLifecycleValidated = $true",
  ).replace(
    '[string]$ownershipState.OwnerState -cin @("caller", "controller")',
    "$null -eq $worker -and $DeleteSqlFileOnCompletion -and $sqlLifecycleValidated",
  ).split("\n");
  const resolveIndex = lines.findIndex((line) => line.includes("$effectiveProcessTimeout = Resolve-PsqlProcessTimeoutMilliseconds"));
  const [resolveLine] = lines.splice(resolveIndex, 1);
  const tryIndex = lines.findIndex((line) => line.trim() === "try {");
  lines.splice(tryIndex + 1, 0, resolveLine);
  return lines.join("\n");
})));
expectReject("guard acepta manifest.local.json", () => validateWorkerSourceLifecycle(mutateHarnessFunction("Assert-DisposableWorkerSqlPath", (block) => block.replace("$canonicalFileName -cmatch '^worker_[a-z0-9_]+_[0-9a-f]{32}\\.sql$'", '$canonicalFileName -cne "manifest.local.json"'))));
expectReject("guard acepta final-postcheck.local.txt", () => validateWorkerSourceLifecycle(mutateHarnessFunction("Assert-DisposableWorkerSqlPath", (block) => block.replace("$canonicalFileName -cmatch '^worker_[a-z0-9_]+_[0-9a-f]{32}\\.sql$'", '($canonicalFileName -cmatch \'^worker_[a-z0-9_]+_[0-9a-f]{32}\\.sql$\' -or $canonicalFileName -ceq "final-postcheck.local.txt")'))));
expectReject("guard acepta evidencia publishing", () => validateWorkerSourceLifecycle(mutateHarnessFunction("Assert-DisposableWorkerSqlPath", (block) => block.replace("$canonicalFileName -cmatch '^worker_[a-z0-9_]+_[0-9a-f]{32}\\.sql$'", '($canonicalFileName -cmatch \'^worker_[a-z0-9_]+_[0-9a-f]{32}\\.sql$\' -or $canonicalFileName -ceq "multisession-evidence.local.txt.publishing")'))));
expectReject("guard acepta worker SQL sin GUID", () => validateWorkerSourceLifecycle(mutateHarnessFunction("Assert-DisposableWorkerSqlPath", (block) => block.replace("$canonicalFileName -cmatch '^worker_[a-z0-9_]+_[0-9a-f]{32}\\.sql$'", '($canonicalFileName -cmatch \'^worker_[a-z0-9_]+_[0-9a-f]{32}\\.sql$\' -or $canonicalFileName -ceq "worker_fixture.sql")'))));
expectReject("guard acepta prefijo o GUID en mayúsculas", () => validateWorkerSourceLifecycle(mutateHarnessFunction("Assert-DisposableWorkerSqlPath", (block) => block.replace("$canonicalFileName -cmatch '^worker_[a-z0-9_]+_[0-9a-f]{32}\\.sql$'", '($canonicalFileName -cmatch \'^worker_[a-z0-9_]+_[0-9a-f]{32}\\.sql$\' -or $canonicalFileName -ceq "WORKER_fixture_ABCDEFABCDEFABCDEFABCDEFABCDEFAB.sql")'))));
expectReject("guard acepta sólo prefijo worker_", () => validateWorkerSourceLifecycle(mutateHarnessFunction("Assert-DisposableWorkerSqlPath", (block) => block.replace("$canonicalFileName -cmatch '^worker_[a-z0-9_]+_[0-9a-f]{32}\\.sql$'", '$canonicalFileName.StartsWith("worker_")'))));
expectReject("guard acepta sólo extensión sql", () => validateWorkerSourceLifecycle(mutateHarnessFunction("Assert-DisposableWorkerSqlPath", (block) => block.replace("$canonicalFileName -cmatch '^worker_[a-z0-9_]+_[0-9a-f]{32}\\.sql$'", '$canonicalFileName.EndsWith(".sql")'))));
expectReject("guard pierde comparación case-sensitive", () => validateWorkerSourceLifecycle(mutateHarnessFunction("Assert-DisposableWorkerSqlPath", (block) => block.replace("$canonicalFileName -cmatch", "$canonicalFileName -match"))));
expectReject("guard acepta path anidado", () => validateWorkerSourceLifecycle(mutateHarnessFunction("Assert-DisposableWorkerSqlPath", (block) => block.replace("[string]::Equals($canonicalParent, $canonicalRunDirectory, [System.StringComparison]::OrdinalIgnoreCase)", "$full.StartsWith($canonicalRunDirectory)"))));
expectReject("guard omite reparse point", () => validateWorkerSourceLifecycle(mutateHarnessFunction("Assert-DisposableWorkerSqlPath", (block) => block.replace("[System.IO.FileAttributes]::ReparsePoint", "[System.IO.FileAttributes]::Normal"))));
expectReject("setter caller muta antes de validar identidad", () => validatePsqlProcessTimeoutContract(mutateHarnessFunction("Set-PsqlDisposableCallerOwnership", (block) => block.replace("  $identity = Get-PsqlDisposableIdentity", '  $State.OwnerState = "caller"\n  $identity = Get-PsqlDisposableIdentity'))));
expectReject("caller y controller se superponen", () => validatePsqlProcessTimeoutContract(mutateHarnessFunction("Set-PsqlDisposableCallerOwnership", (block) => block.replace('$State.OwnerState = "caller"', '$State.OwnerState = "controller"'))));
expectReject("controller y starter se superponen", () => validatePsqlProcessTimeoutContract(mutateHarnessFunction("Set-PsqlDisposableStarterOwnership", (block) => block.replace('$State.OwnerState = "starter"', '$State.OwnerState = "starter"\n  $State.OwnerState = "controller"'))));
expectReject("controller reacquiere después de completed", () => validatePsqlProcessTimeoutContract(mutateHarnessFunction("Set-PsqlDisposableControllerOwnership", (block) => block.replace('@("none", "caller")', '@("none", "caller", "completed")'))));
expectReject("controller cleanup elimina una hoja arbitraria", () => validatePsqlProcessTimeoutContract(mutateHarnessFunction("Invoke-PsqlDisposableOwnershipCleanup", (block) => block.replaceAll("Assert-PsqlDisposableFrozenIdentity -State $State", "Assert-DisposableWorkerSqlPath -SqlFile $State.CanonicalPath -RunDirectory $State.CanonicalRunDirectory"))));
expectReject("outer cleanup vuelve a usar not WorkerOwns", () => validatePsqlProcessTimeoutContract(mutateHarnessFunction("Invoke-PsqlSqlOuterHandoffCleanup", (block) => block.replace('[string]$State.OwnerState -cin @("caller", "controller")', "-not $State.WorkerOwns"))));
expectReject("cleanup interno exitoso vuelve a contabilizar dos borrados", () => validatePsqlProcessTimeoutContract(mutateHarnessFunction("Assert-Db24TransientSqlIdentityAndStarterEscrowFixtures", (block) => block.replace("$completedState.CleanupInvocationCount -eq 1", "$completedState.CleanupInvocationCount -eq 2"))));
expectReject("reemplazo con hash distinto puede borrarse", () => validatePsqlProcessTimeoutContract(mutateHarnessFunction("Assert-PsqlDisposableFrozenIdentity", (block) => block.replace("(Get-Sha256 -Path $State.CanonicalPath) -ceq [string]$State.ExpectedSha256", "$true"))));
expectReject("Start-PsqlWorker descarta el cleanup estructurado", () => validatePsqlProcessTimeoutContract(mutateHarnessFunction("Start-PsqlWorker", (block) => block.replace("$startCleanup = Invoke-PsqlWorkerStartFailureCleanup", "[void](Invoke-PsqlWorkerStartFailureCleanup"))));
expectReject("proceso inicia sin escrow starter", () => validatePsqlProcessTimeoutContract(mutateHarnessFunction("Start-PsqlWorker", (block) => block.replace("Set-PsqlDisposableStarterOwnership", "Omitted-PsqlDisposableStarterOwnership"))));
expectReject("referencia de proceso se guarda después de lectores", () => validatePsqlProcessTimeoutContract(mutateHarnessFunction("Start-PsqlWorker", (block) => block.replace("    $stdoutTask = $process.StandardOutput.ReadToEndAsync()", "    $stdoutTask = $process.StandardOutput.ReadToEndAsync()\n    Set-PsqlDisposableStarterOwnership -State $startState -Process $process -SqlFile $SqlFile -RunDirectory $RunDirectory").replace("      Set-PsqlDisposableStarterOwnership -State $startState -Process $process -SqlFile $SqlFile -RunDirectory $RunDirectory", "      Omitted-PsqlDisposableStarterOwnership"))));
expectReject("PID se registra antes del escrow starter", () => validatePsqlProcessTimeoutContract(mutateHarnessFunction("Start-PsqlWorker", (block) => block.replace("    $stdoutTask = $process.StandardOutput.ReadToEndAsync()", '    $startState.LocalPidAddAttempted = $true\n    $stdoutTask = $process.StandardOutput.ReadToEndAsync()'))));
expectReject("fallo de terminación permite borrar SQL", () => validatePsqlProcessTimeoutContract(mutateHarnessFunction("Invoke-PsqlWorkerStartFailureCleanup", (block) => block.replace("$State.ProcessTerminationObserved -and $cleanupProcess.HasExited", "$true"))));
expectReject("caller trata starter como controller sin worker", () => validatePsqlProcessTimeoutContract(mutateHarnessFunction("Invoke-PsqlFile", (block) => block.replace('@("caller", "controller")', '@("caller", "controller", "starter")'))));
expectReject("paired cleanup clasifica starter como no-owner", () => validatePsqlProcessTimeoutContract(mutateHarnessFunction("Remove-UnownedTransientSqlFile", (block) => block.replace('@("starter", "worker")', '@("worker")'))));
expectReject("PID removal precede terminación observada", () => validatePsqlProcessTimeoutContract(mutateHarnessFunction("Invoke-PsqlWorkerStartFailureCleanup", (block) => block.replace("PSQL_START_PROCESS_TERMINATE", "PROCESS_TERMINATION_OMITTED"))));
expectReject("SQL removal precede terminación observada", () => validatePsqlProcessTimeoutContract(mutateHarnessFunction("Invoke-PsqlWorkerStartFailureCleanup", (block) => block.replace("PSQL_START_DISPOSABLE_SQL_REMOVE", "DISPOSABLE_SQL_REMOVE_BEFORE_EXIT"))));
expectReject("fixture DB-24 no crea archivos no-worker físicos", () => validatePsqlProcessTimeoutContract(mutateHarnessFunction("Assert-Db24TransientSqlIdentityAndStarterEscrowFixtures", (block) => block.replaceAll("[System.IO.File]::WriteAllText", "Omitted-PhysicalFixtureWrite"))));
expectReject("fixture DB-24 inicia Process.Start", () => validatePsqlProcessTimeoutContract(mutateHarnessFunction("Assert-Db24TransientSqlIdentityAndStarterEscrowFixtures", (block) => block.replace("  try {", "  [void]$process.Start()\n  try {"))));
expectReject("completed permite otro Remove-Item", () => validatePsqlProcessTimeoutContract(mutateHarnessFunction("Invoke-PsqlSqlOuterHandoffCleanup", (block) => block.replace(
  '  if ([string]$State.OwnerState -ceq "completed" -and',
  '  if ([string]$State.OwnerState -ceq "completed" -and\n    (Remove-Item -LiteralPath $State.CanonicalPath -Force) -and',
))));
expectReject("DB-25 New-SqlFile vuelve a retornar pathname", () => validatePsqlProcessTimeoutContract(mutateHarnessFunction("New-SqlFile", (block) => block.replace("return $artifact", "return $creationState.Path"))));
expectReject("DB-25 artefacto omite ExpectedByteLength", () => validatePsqlProcessTimeoutContract(mutateHarnessFunction("New-PsqlVerifiedTransientArtifact", (block) => block.replaceAll("ExpectedByteLength = [long]$identity.ExpectedByteLength", "OmittedExpectedByteLength = [long]$identity.ExpectedByteLength"))));
expectReject("DB-25 caller recalcula confianza inicial", () => validatePsqlProcessTimeoutContract(mutateHarnessFunction("New-PsqlVerifiedTransientArtifact", (block) => block.replace("  return [pscustomobject]@{", "  $replacementIdentity = Get-PsqlDisposableIdentity -SqlFile $identity.CanonicalPath -RunDirectory $identity.CanonicalRunDirectory\n  return [pscustomobject]@{"))));
expectReject("DB-25 crea ownership nuevo tras New-SqlFile", () => validatePsqlProcessTimeoutContract(mutateHarnessFunction("Invoke-PsqlSql", (block) => block.replace("$handoffState = $artifact.OwnershipState", "$handoffState = New-PsqlDisposableOwnershipState -SqlFile $artifact.Path -RunDirectory $RunDirectory"))));
expectReject("DB-25 controller sobrescribe identidad congelada", () => validatePsqlProcessTimeoutContract(mutateHarnessFunction("Set-PsqlDisposableControllerOwnership", (block) => block.replace("  Assert-PsqlDisposableStateIdentity -State $State -Identity $identity", "  Assert-PsqlDisposableStateIdentity -State $State -Identity $identity\n  $State.FrozenExpectedSha256 = $identity.ExpectedSha256"))));
expectReject("DB-25 adopta reemplazo como hash confiable", () => validatePsqlProcessTimeoutContract(mutateHarnessFunction("Assert-PsqlDisposableStateIdentity", (block) => block.replace("[string]$State.ExpectedSha256 -ceq [string]$Identity.ExpectedSha256", "$State.FrozenExpectedSha256 = [string]$Identity.ExpectedSha256"))));
expectReject("DB-25 lee Process.Id antes del escrow", () => validatePsqlProcessTimeoutContract(mutateHarnessFunction("Start-PsqlWorker", (block) => block.replace("    $processId = Get-PsqlProcessId -Process $process\n", "").replace("      $startState.Process = $process", "      $processId = Get-PsqlProcessId -Process $process\n      $startState.Process = $process"))));
expectReject("DB-25 ejecuta assertion post-Start antes del escrow", () => validatePsqlProcessTimeoutContract(mutateHarnessFunction("Start-PsqlWorker", (block) => block.replace("    $processStarted = $true", "    $processStarted = $true\n    Assert-Condition -Condition $true -Code \"unsafe_post_start_assertion\""))));
expectReject("DB-25 almacena StartInfo después de Process.Start", () => validatePsqlProcessTimeoutContract(mutateHarnessFunction("Start-PsqlWorker", (block) => block.replace("  $startState.StartInfo = $startInfo\n", "").replace("    $processStarted = $true", "    $processStarted = $true\n    $startState.StartInfo = $startInfo"))));
expectReject("DB-25 cleanup genérico omite sanitización", () => validatePsqlProcessTimeoutContract(mutateHarnessFunction("Invoke-PsqlWorkerStartFailureCleanup", (block) => block.replace("PSQL_START_INFO_CLEAR", "START_INFO_SANITIZATION_OMITTED"))));
expectReject("DB-25 worker retorna con material PostgreSQL", () => validatePsqlProcessTimeoutContract(mutateHarnessFunction("Start-PsqlWorker", (block) => block.replace("Test-PsqlStartInfoContainsPgMaterial", "Test-UnrelatedStartInfoState"))));
expectReject("DB-25 holder runtime captura estado local después del starter", () => validateDb25VerifiedIdentityAndEscrowContract(mutateHarnessFunction("Start-StagedRuntimeAdvisoryHolder", (block) => block.replace("    $processStartState.Process = $process\n    $processStartState.ProcessStarted = $true\n", "").replace("    $DisposableSqlOwnershipState.OwnerState = \"starter\"", "    $DisposableSqlOwnershipState.OwnerState = \"starter\"\n    $processStartState.Process = $process\n    $processStartState.ProcessStarted = $true"))));
expectReject("DB-25 cleanup pierde fallback de proceso", () => validatePsqlProcessTimeoutContract(mutateHarnessFunction("Start-PsqlWorker", (block) => block.replace("-FallbackProcess $fallbackProcess -FallbackProcessStarted $processStarted -FallbackStartInfo $fallbackStartInfo", "-FallbackProcessStarted $processStarted -FallbackStartInfo $fallbackStartInfo"))));
expectReject("DB-25 cleanup externo se invoca directamente", () => validateDb25VerifiedIdentityAndEscrowContract(mutateHarnessFunction("Invoke-PsqlSql", (block) => block.replace("$handoffCleanup = Invoke-OrchestrationCleanup -EmitFailureMarkers -CleanupOperations @(", "$handoffCleanup = Invoke-PsqlSqlOuterHandoffCleanup -State $handoffState\n  $ignoredOperations = @("))));
expectReject("DB-25 cleanup externo reemplaza el primario", () => validatePsqlProcessTimeoutContract(mutateHarnessFunction("Invoke-PsqlSql", (block) => block.replace("Complete-OrchestrationCleanup -PrimaryError $handoffError", "Complete-OrchestrationCleanup -PrimaryError $null"))));
expectReject("DB-25 invariant acepta starter sin Process", () => validateDb25VerifiedIdentityAndEscrowContract(mutateHarnessFunction("Assert-PsqlDisposableOwnershipInvariant", (block) => block.replace("$State.ProcessStartObserved -and $null -ne $State.Process", "$State.ProcessStartObserved -and $true"))));
expectReject("DB-25 invariant acepta worker sin Worker", () => validateDb25VerifiedIdentityAndEscrowContract(mutateHarnessFunction("Assert-PsqlDisposableOwnershipInvariant", (block) => block.replace("$workerMatches = $null -ne $State.Worker", "$workerMatches = $true"))));
expectReject("DB-25 invariant acepta completed sin terminación", () => validateDb25VerifiedIdentityAndEscrowContract(mutateHarnessFunction("Assert-PsqlDisposableOwnershipInvariant", (block) => block.replace("(-not $State.ProcessStartObserved -or $State.ProcessTerminationObserved)", "$true"))));
expectReject("DB-25 SQL protegido recibe owner transitorio", () => validateDb25VerifiedIdentityAndEscrowContract(mutateHarnessFunction("Assert-Db25VerifiedArtifactAndProcessEscrowFixtures", (block) => block.replace('protectedOwnerState.OwnerState -ceq "none" -and -not $protectedOwnerState.IdentityFrozen', 'protectedOwnerState.OwnerState -ceq "controller" -and $protectedOwnerState.IdentityFrozen'))));
expectReject("DB-25 ValidateOnly inicia proceso", () => validateDb25VerifiedIdentityAndEscrowContract(mutateHarnessFunction("Assert-Db25VerifiedArtifactAndProcessEscrowFixtures", (block) => block.replace("  $fixtureError = $null", "  [void]$process.Start()\n  $fixtureError = $null"))));
expectReject("DB-25 prueba cleanup externo sólo de forma aislada", () => validateDb25VerifiedIdentityAndEscrowContract(mutateHarnessFunction("Assert-Db25VerifiedArtifactAndProcessEscrowFixtures", (block) => block.replaceAll("Invoke-PsqlSql -Connection", "Invoke-PsqlSqlOuterHandoffCleanup -Connection"))));
expectReject("DB-26 setter muta y lanza sin rollback", () => validateDb26WorkerHandoffAndMarkerDeadlineContract(mutateHarnessFunction("Set-PsqlDisposableWorkerOwnership", (block) => block.replace(
  "    $State.Worker = $previousWorker\n    $State.OwnerState = $previousOwnerState\n    $State.WorkerTransferCount = $previousWorkerTransferCount",
  "    # rollback omitido por fixture negativa",
))));
expectReject("DB-26 WorkerTransferCount queda incrementado tras fallo", () => validateDb26WorkerHandoffAndMarkerDeadlineContract(mutateHarnessFunction("Set-PsqlDisposableWorkerOwnership", (block) => block.replace(
  "    $State.OwnerState = $previousOwnerState\n    $State.WorkerTransferCount = $previousWorkerTransferCount\n    throw $transitionError",
  "    $State.OwnerState = $previousOwnerState\n    $State.WorkerTransferCount = $previousWorkerTransferCount + 1\n    throw $transitionError",
))));
expectReject("DB-26 OwnerState queda worker tras fallo", () => validateDb26WorkerHandoffAndMarkerDeadlineContract(mutateHarnessFunction("Set-PsqlDisposableWorkerOwnership", (block) => block.replace(
  "    $State.OwnerState = $previousOwnerState",
  '    $State.OwnerState = "worker"',
))));
expectReject("DB-26 Worker queda poblado tras fallo", () => validateDb26WorkerHandoffAndMarkerDeadlineContract(mutateHarnessFunction("Set-PsqlDisposableWorkerOwnership", (block) => block.replace(
  "    $State.Worker = $previousWorker",
  "    $State.Worker = $Worker",
))));
expectReject("DB-26 StartInfo vuelve a validarse después del handoff", () => validateDb26WorkerHandoffAndMarkerDeadlineContract(mutateHarnessFunction("Start-PsqlWorker", (block) => block.replace(
  "      Set-PsqlDisposableWorkerOwnership -State $startState -Worker $worker\n      return $worker",
  "      Set-PsqlDisposableWorkerOwnership -State $startState -Worker $worker\n      Assert-Condition -Condition (-not (Test-PsqlStartInfoContainsPgMaterial -StartInfo $startInfo)) -Code \"unsafe_post_transfer_start_info\"\n      return $worker",
))));
expectReject("DB-26 otra aserción queda después del handoff", () => validateDb26WorkerHandoffAndMarkerDeadlineContract(mutateHarnessFunction("Start-PsqlWorker", (block) => block.replace(
  "      Set-PsqlDisposableWorkerOwnership -State $startState -Worker $worker\n      return $worker",
  "      Set-PsqlDisposableWorkerOwnership -State $startState -Worker $worker\n      Assert-PsqlDisposableOwnershipInvariant -State $startState\n      return $worker",
))));
expectReject("DB-26 cleanup genérico deja SQL worker después de terminar", () => validateDb26WorkerHandoffAndMarkerDeadlineContract(mutateHarnessFunction("Invoke-PsqlWorkerStartFailureCleanup", (block) => block.replace(
  "        Remove-DisposableWorkerSqlFile -Worker $State.Worker",
  "        # SQL worker retenido por fixture negativa",
))));
expectReject("DB-26 Invoke-PsqlFile clasifica worker nulo como controller", () => validateDb26WorkerHandoffAndMarkerDeadlineContract(mutateHarnessFunction("Invoke-PsqlFile", (block) => block.replace(
  '[string]$ownershipState.OwnerState -ceq "worker"',
  '[string]$ownershipState.OwnerState -ceq "controller"',
))));
expectReject("DB-26 setter staged deja OwnerState worker", () => validateDb26WorkerHandoffAndMarkerDeadlineContract(mutateHarnessFunction("Set-PsqlDisposableWorkerOwnership", (block) => block.replace(
  "    $State.OwnerState = $previousOwnerState",
  '    $State.OwnerState = "worker"',
))));
expectReject("DB-26 holder staged limpia sólo starter y controller", () => validateDb26WorkerHandoffAndMarkerDeadlineContract(mutateHarnessFunction("Start-StagedRuntimeAdvisoryHolder", (block) => block.replace(
  'elseif ($processStartState.ProcessTerminationObserved -and [string]$DisposableSqlOwnershipState.OwnerState -ceq "worker")',
  'elseif ($processStartState.ProcessTerminationObserved -and [string]$DisposableSqlOwnershipState.OwnerState -ceq "starter")',
))));
expectReject("DB-26 marcador sólo comprueba antes de leer", () => validateDb26WorkerHandoffAndMarkerDeadlineContract(mutateHarnessFunction("Wait-StagedRuntimeAdvisoryHolderMarker", (block) => block
  .replace("    $postReadMonotonicTimestamp = Get-MonotonicTimestamp", "    $postReadMonotonicTimestamp = $beforeReadTimestamp")
  .replace("      $acceptedMonotonicTimestamp = Get-MonotonicTimestamp", "      $acceptedMonotonicTimestamp = $beforeReadTimestamp"))));
expectReject("DB-26 match retorna sin deadline post-read", () => validateDb26WorkerHandoffAndMarkerDeadlineContract(mutateHarnessFunction("Wait-StagedRuntimeAdvisoryHolderMarker", (block) => block.replace(
  '-FailureCode "staged_runtime_holder_marker_late_response_rejected"',
  '-FailureCode "staged_runtime_holder_marker_post_read_check_omitted"',
))));
expectReject("DB-26 parse retorna sin deadline final", () => validateDb26WorkerHandoffAndMarkerDeadlineContract(mutateHarnessFunction("Wait-StagedRuntimeAdvisoryHolderMarker", (block) => {
  const token = '-FailureCode "staged_runtime_holder_marker_late_response_rejected"';
  const index = block.lastIndexOf(token);
  assert.ok(index >= 0, "Fixture negativa DB-26 requiere el cerco final");
  return `${block.slice(0, index)}-FailureCode "staged_runtime_holder_marker_final_check_omitted"${block.slice(index + token.length)}`;
})));
expectReject("DB-26 acepta marcador en timeout más uno", () => validateDb26WorkerHandoffAndMarkerDeadlineContract(mutateHarnessFunction("Wait-StagedRuntimeAdvisoryHolderMarker", (block) => block.replace(
  "-TimeoutMilliseconds $TimeoutMilliseconds `\n        -FailureCode \"staged_runtime_holder_marker_late_response_rejected\"",
  "-TimeoutMilliseconds ($TimeoutMilliseconds + 1) `\n        -FailureCode \"staged_runtime_holder_marker_late_response_rejected\"",
))));
expectReject("DB-26 timestamp observado se captura después del check", () => validateDb26WorkerHandoffAndMarkerDeadlineContract(mutateHarnessFunction("Wait-StagedRuntimeAdvisoryHolderMarker", (block) => block.replace(
  "ObservedMonotonicTimestamp = [long]$acceptedMonotonicTimestamp",
  "ObservedMonotonicTimestamp = [long](Get-MonotonicTimestamp)",
))));
expectReject("DB-26 MS11–MS17 omiten evidencia timely", () => validateDb26WorkerHandoffAndMarkerDeadlineContract(mutateHarnessFunction("Invoke-ActivityConcurrencyScenarios", (block) => block.replace(
  "HolderReleaseMarkerWithinDeadline = $ms13Pair.HolderReleaseMarkerWithinDeadline",
  "HolderReleaseDeadlineOmitted = $ms13Pair.HolderReleaseMarkerWithinDeadline",
))));
expectReject("CompletedPhase NONE rechazado", () => validateManifestStateMachine(harness.replace('$completedPhase -ceq "NONE" -or $completedIndex -ge 0', "$completedIndex -ge 0")));
expectReject("fase parcial reanudable", () => validateManifestStateMachine(harness.replace('Throw-StableFailure -Code "resume_incomplete_phase_rejected"', 'Throw-StableFailure -Code "resume_partial_allowed"')));
expectReject("PHASE_05 parcial declarada completa", () => validateManifestStateMachine(harness.replace('phase_completion_scenario_set_rejected', 'phase_completion_partial_allowed')));
expectReject("RunId rechazado reanudable", () => validateManifestStateMachine(harness.replace('resume_rejected_run_rejected', 'resume_rejected_run_allowed')));
expectReject("RunId con evidencia aprobada y rechazada", () => validateManifestStateMachine(harness.replace('run_evidence_conflict_rejected', 'run_evidence_conflict_allowed')));
expectReject("ActivePhase aceptada como frontera segura", () => validateManifestStateMachine(harness.replace('resume_incomplete_phase_rejected', 'resume_active_phase_allowed')));
expectReject("ready/PHASE_06 aceptado", () => validateManifestStateMachine(harness.replace('ready_completed_phase_rejected', 'ready_phase06_allowed')));
expectReject("Execute infiere aprobación por índice 6", () => validateManifestStateMachine(harness.replace('execute_completed_phase_rejected', 'execute_phase06_allowed')));
expectReject("marcador final sin releer evidencia", () => validateManifestStateMachine(mutateHarnessFunction("Invoke-ExecuteMode", (block) => block.replace("$manifest = Assert-FinalApprovedState -Paths $paths", "$manifest = $manifest"))));
expectReject("Set-ManifestPhase congela ceros para todas las fases", () => validateManifestStateMachine(mutateHarnessFunction("Set-ManifestPhase", (block) => block.replace("$Manifest.ExpectedDiagnosticCounts = $ExpectedDiagnosticCounts", '$Manifest.ExpectedDiagnosticCounts = [ordered]@{ FixturePeriods = 0; Activities = 0; AuditEvents = 0; OpenWorkers = 0; HeldAdvisoryLocks = 0; TemporaryObjects = 0 }'))));
expectReject("PHASE_02 congela cero actividades", () => validatePhaseBoundaryContract(mutateHarnessFunction("Get-ExpectedDiagnosticCountsForPhase", (block) => block.replace('{ 1 } else { 0 }', '{ 0 } else { 0 }'))));
expectReject("PHASE_02 omite fixture esperado", () => validatePhaseBoundaryContract(mutateHarnessFunction("Invoke-Phase02InstallationMatrix", (block) => block.replace("-ExpectedActivityFixture $expectedActivityFixture", "-ExpectedActivityFixture $null"))));
expectReject("reanudar acepta fingerprint alterado", () => validateManifestStateMachine(mutateHarnessFunction("Assert-ResumeContract", (block) => block.replace('$activityFixture.RowFingerprint -ceq [string]$Manifest.ExpectedActivityFixture.RowFingerprint', '$true'))));
expectReject("reanudar acepta actividad adicional", () => validateManifestStateMachine(mutateHarnessFunction("Assert-ResumeContract", (block) => block.replace('$activityFixture.Activities -eq 1 -and $activityFixture.MatchingRows -eq 1', '$activityFixture.MatchingRows -eq 1'))));
expectReject("PHASE_03 retiene fixture", () => validatePhaseBoundaryContract(mutateHarnessFunction("Invoke-Phase03RollbackMatrix", (block) => block.replace('$Manifest.InstallationFixtureId = $null', '$Manifest.InstallationFixtureId = $ActivityId'))));
expectReject("if/if/elseif omite invariantes running", () => validateManifestStateMachine(mutateHarnessFunction("Assert-ManifestRecord", (block) => block.replace('if ($runStatus -ceq "running")', 'elseif ($runStatus -ceq "running")'))));
expectReject("SourceHead ausente del manifiesto", () => validateManifestStateMachine(mutateHarnessFunction("New-Manifest", (block) => block.replace("SourceHead = Get-SourceHead", "OmittedSource = Get-SourceHead"))));
for (const field of ["MigrationSha256", "RollbackSha256", "HarnessSha256"]) {
  expectReject(`${field} ausente del manifiesto`, () => validateManifestStateMachine(mutateHarnessFunction("New-Manifest", (block) => block.replace(`${field} =`, `Omitted${field} =`))));
}
expectReject("PostcheckOnly omite procedencia SourceHead", () => validatePostcheckDiagnostic(mutatePostcheck((block) => block.replace('$runIdMatches -and $sourceHeadMatches -and $migrationHashMatches', '$runIdMatches -and $migrationHashMatches'))));
expectReject("estado parcial omite banderas diagnósticas", () => validatePostcheckDiagnostic(mutateRenderer((block) => block.replace('"OBJECT_AUDIT_TABLE|$([int]$Diagnostic.AuditTablePresent)",', ''))));
expectReject("estado parcial lee una propiedad ausente", () => validatePostcheckDiagnostic(mutateHarnessFunction("Invoke-ReadOnlyDatabaseDiagnostic", (block) => block.replace("    FunctionInventoryCount = $null\n", ""))));
expectReject("estado parcial carece de NOT_APPLICABLE", () => validatePostcheckDiagnostic(mutateHarnessFunction("Get-DiagnosticInventoryDisplayValue", (block) => block.replace('return "NOT_APPLICABLE"', 'return ""'))));
expectReject("postcheck ignora evidencia final parcial", () => validatePostcheckDiagnostic(mutateHarnessFunction("Get-TerminalArtifactClassification", (block) => block.replace('$Inventory.ApprovedPostcheckExists -or $Inventory.ApprovedEvidenceExists', '$Inventory.ApprovedEvidenceExists'))));
expectReject("aprobación ordinal", () => validateExplicitApprovals(`${harness}\nAdd-ApprovedScenario -Ordinal 13`, scenarioIds));
expectReject("un helper aprueba varios IDs", () => validateExplicitApprovals(`${harness}\nInvoke-ScenarioGroup\nApprove-ScenarioResult -Result $ms13\nApprove-ScenarioResult -Result $ms14`, scenarioIds));
expectReject("FailureScenario de grupo", () => validateExplicitApprovals(`${harness}\n$FailureScenario = "RUNTIME_GROUP"`, scenarioIds));
expectReject("MS13 sin publicación real", () => {
  const block = extractFunction(harness, "Invoke-ActivityConcurrencyScenarios");
  validateRuntimeSemantics(harness.replace(block, block.replace("publish_activity('$ActivityId'::uuid)", "get_academic_period_for_date(current_date)")));
});
expectReject("MS14 sin cambio de start_date", () => {
  const block = extractFunction(harness, "Invoke-ActivityConcurrencyScenarios");
  validateRuntimeSemantics(harness.replace(block, block.replace("set start_date = a.start_date + 1", "set description = a.description")));
});
expectReject("MS17 sin resolver", () => {
  const block = extractFunction(harness, "Invoke-ActivityConcurrencyScenarios");
  validateRuntimeSemantics(harness.replace(block, block.replaceAll("IndependentResolverMatches", "UnrelatedAssertion")));
});
expectReject("MS18 con UUID inexistente", () => {
  const block = extractFunction(harness, "Invoke-WallClockScenarios");
  validateRuntimeSemantics(harness.replace(block, block.replace("select * from public.publish_activity('$activityId'::uuid);", "select * from public.publish_activity(gen_random_uuid());")));
});
expectReject("MS18/MS19 sólo prueban CLOCK_CROSSED", () => validateRuntimeSemantics(mutateHarnessFunction("Invoke-WallClockScenarios", (block) => block.replaceAll("CLOCK_STILL_FUTURE_AT_WAIT", "CLOCK_FUTURE_PROOF_OMITTED"))));
expectReject("MS18/MS19 hardcodean futuro", () => validateRuntimeSemantics(mutateHarnessFunction("Invoke-WallClockScenarios", (block) => block.replace("StartStillFutureWhenWaitObserved = $startStillFutureWhenWaitObserved", "StartStillFutureWhenWaitObserved = $true"))));
expectReject("MS18/MS19 invierten cruce y espera", () => validateRuntimeSemantics(mutateHarnessFunction("Invoke-WallClockScenarios", (block) => block.replace("Wait-ForObserverCondition -FailureCode ($Label + \"_wait_not_observed\")", "Wait-ForObserverCondition -FailureCode ($Label + \"_clock_crossing_not_observed\")"))));
expectReject("MS18/MS19 aceptan sólo duración de sleep", () => validateRuntimeSemantics(mutateHarnessFunction("Invoke-WallClockScenarios", (block) => block.replaceAll("CLOCK_STILL_FUTURE_AT_WAIT", "SLEEP_DURATION_ONLY").replaceAll("CLOCK_CROSSED", "SLEEP_COMPLETED"))));
expectReject("MS20 con JWT aleatorio", () => {
  const block = extractFunction(harness, "Invoke-AuthorityLossScenario");
  validateRuntimeSemantics(harness.replace(block, block.replace("select set_config('request.jwt.claim.sub', '$candidateId', true);", "select set_config('request.jwt.claim.sub', gen_random_uuid()::text, true);")));
});
expectReject("observer genérico restaura retorno Boolean inmediato", () => validateGenericObserverContract(mutateHarnessFunction("Wait-ForObserverCondition", (block) => block.replace("$probeResult = & $Probe", "if (& $Probe) { return }"))));
expectReject("observer genérico usa DateTime.UtcNow", () => validateGenericObserverContract(mutateHarnessFunction("Wait-ForObserverCondition", (block) => block.replace("$observerStartedTimestamp = Get-MonotonicTimestamp", "$observerStartedTimestamp = [DateTime]::UtcNow"))));
expectReject("observer acepta true después del timeout", () => validateGenericObserverContract(mutateHarnessFunction("Resolve-ObserverProbeOutcome", (block) => block.replace("$ProbeElapsedMilliseconds -gt $ProbeTimeoutMilliseconds -or $TotalElapsedMilliseconds -gt $TimeoutMilliseconds", "$ProbeElapsedMilliseconds -gt $ProbeTimeoutMilliseconds"))));
expectReject("probe nominal de 30 segundos conserva timeout SQL de 90 segundos", () => validateGenericObserverContract(mutateHarnessFunction("Invoke-AdvisoryPairObservationProbe", (block) => block.replace("StatementTimeoutMilliseconds $script:ObserverProbeCommandTimeoutMilliseconds", "StatementTimeoutMilliseconds 90000"))));
expectReject("probe genérico retorna Boolean sin evidencia", () => validateGenericObserverContract(mutateHarnessFunction("Invoke-RollbackRelationHolderObservationProbe", (block) => block.replace("return [pscustomobject]@{ Satisfied = $satisfied; Evidence = $evidence; TerminalFailureCode = $null }", "return $satisfied"))));
expectReject("observación advisory comprueba sólo waiter no concedido", () => validateAdvisoryPairContract(mutateHarnessFunction("Get-AdvisoryPairObservationSql", (block) => block.replace("exact_holder_count = 1 and exact_waiter_count = 1 and holder_advisory_granted and waiter_advisory_ungranted", "exact_waiter_count = 1 and waiter_advisory_ungranted"))));
expectReject("observación advisory omite holder concedido", () => validateAdvisoryPairContract(mutateHarnessFunction("Get-AdvisoryPairObservationSql", (block) => block.replace("and holder_advisory_granted and waiter_advisory_ungranted", "and waiter_advisory_ungranted"))));
expectReject("observación advisory acepta holder duplicado", () => validateAdvisoryPairContract(mutateHarnessFunction("Get-AdvisoryPairObservationSql", (block) => block.replace("exact_holder_count = 1 and exact_waiter_count = 1", "exact_holder_count >= 1 and exact_waiter_count = 1"))));
expectReject("observación advisory acepta waiter duplicado", () => validateAdvisoryPairContract(mutateHarnessFunction("Get-AdvisoryPairObservationSql", (block) => block.replace("exact_holder_count = 1 and exact_waiter_count = 1", "exact_holder_count = 1 and exact_waiter_count >= 1"))));
expectReject("observación advisory omite liveness del holder", () => validateAdvisoryPairContract(mutateHarnessFunction("Get-AdvisoryPairObservationSql", (block) => block.replace("and holder_alive and waiter_alive and pids_differ", "and waiter_alive and pids_differ"))));
expectReject("observación advisory omite liveness del waiter", () => validateAdvisoryPairContract(mutateHarnessFunction("Get-AdvisoryPairObservationSql", (block) => block.replace("and holder_alive and waiter_alive and pids_differ", "and holder_alive and pids_differ"))));
expectReject("readiness advisory omite objsubid", () => validateExactSem01AdvisoryIdentity(mutateHarnessFunction("Get-AdvisoryHolderObservationSql", (block) => block.replace("and lock_info.objsubid = $($script:Sem01AdvisoryObjSubId)", ""))));
expectReject("holder del par omite objsubid", () => validateExactSem01AdvisoryIdentity(mutateHarnessFunction("Get-AdvisoryPairObservationSql", (block) => block.replace("and lock_info.objsubid = $($script:Sem01AdvisoryObjSubId)", ""))));
expectReject("waiter del par omite objsubid", () => validateExactSem01AdvisoryIdentity(mutateHarnessFunction("Get-AdvisoryPairObservationSql", (block) => {
  const token = "and lock_info.objsubid = $($script:Sem01AdvisoryObjSubId)";
  const first = block.indexOf(token);
  const second = block.indexOf(token, first + token.length);
  return `${block.slice(0, second)}${block.slice(second + token.length)}`;
})));
expectReject("cruce wall-clock omite objsubid", () => validateExactSem01AdvisoryIdentity(mutateHarnessFunction("Invoke-WallClockScenarios", (block) => block.replace("and lock_info.objsubid = $($script:Sem01AdvisoryObjSubId)", ""))));
expectReject("objsubid uno se acepta", () => validateExactSem01AdvisoryIdentity(harness.replace("$script:Sem01AdvisoryObjSubId = 2", "$script:Sem01AdvisoryObjSubId = 1")));
expectReject("baseline cuenta sólo advisory concedidos", () => validateAdvisoryResidueContract(mutateHarnessFunction("Get-BaselineProbeSql", (block) => block.replaceAll("waiting_advisory_count", "granted_advisory_count").replaceAll("total_advisory_count", "granted_advisory_count"))));
expectReject("PostcheckOnly acepta waiter advisory residual", () => validateAdvisoryResidueContract(mutateHarnessFunction("Invoke-PostcheckOnlyMode", (block) => block.replace("$postcheck.WaitingSem01AdvisoryLocks -eq $manifest.ExpectedDiagnosticCounts.WaitingSem01AdvisoryLocks", "$true"))));
expectReject("MS11 restaura holder temporizado", () => validateStagedRuntimeHolderContract(mutateHarnessFunction("Invoke-CalendarConcurrencyScenarios", (block) => block.replace("select 'MS11_HOLDER_OPERATION_READY|1';", "select 'MS11_HOLDER_OPERATION_READY|1';\nselect pg_sleep(6);"))));
expectReject("MS12 restaura holder temporizado", () => validateStagedRuntimeHolderContract(mutateHarnessFunction("Invoke-CalendarConcurrencyScenarios", (block) => block.replace("select 'MS12_HOLDER_OPERATION_READY|1';", "select 'MS12_HOLDER_OPERATION_READY|1';\nselect pg_sleep(5);"))));
expectReject("holder de calendario restaura sleep", () => validateStagedRuntimeHolderContract(mutateHarnessFunction("Get-CalendarCorrectionHolderStageASql", (block) => block.replace("select '$ReadyMarker|1';", "select '$ReadyMarker|1';\nselect pg_sleep(30);"))));
expectReject("MS16 restaura holder temporizado", () => validateStagedRuntimeHolderContract(mutateHarnessFunction("Invoke-ActivityConcurrencyScenarios", (block) => block.replace("select 'MS16_HOLDER_OPERATION_READY|1';", "select 'MS16_HOLDER_OPERATION_READY|1';\nselect pg_sleep(5);"))));
expectReject("waiter inicia antes del marcador de operación", () => validateStagedRuntimeHolderContract(mutateHarnessFunction("Invoke-AdvisoryWaitPair", (block) => block.replace("$holderReadyObservation = Wait-StagedRuntimeAdvisoryHolderMarker", "$pairResources.WaiterWorker = Start-AdvisoryWaiterAfterHolderReady\n    $holderReadyObservation = Wait-StagedRuntimeAdvisoryHolderMarker"))));
expectReject("holder libera antes del par exacto", () => validateStagedRuntimeHolderContract(mutateHarnessFunction("Invoke-AdvisoryWaitPair", (block) => block.replace("$observation = Wait-ForObserverCondition", "$holderStageBRequest = Send-StagedRuntimeAdvisoryHolderStage -Worker $pairResources.HolderWorker -Stage \"B\"\n    $observation = Wait-ForObserverCondition"))));
expectReject("MS11/MS12 liberan antes de 55P03", () => validateStagedRuntimeHolderContract(mutateHarnessFunction("Invoke-AdvisoryWaitPair", (block) => block.replace("if ($WaitForExpected55P03BeforeRelease)", "$holderStageBRequest = Send-StagedRuntimeAdvisoryHolderStage -Worker $pairResources.HolderWorker -Stage \"B\"\n    if ($WaitForExpected55P03BeforeRelease)"))));
expectReject("MS11/MS12 aceptan éxito del waiter", () => validateStagedRuntimeHolderContract(mutateHarnessFunction("Invoke-AdvisoryWaitPair", (block) => block.replace("Assert-ExpectedSqlState -Result $waiterResult -SqlState \"55P03\"", "Assert-PsqlApproved -Result $waiterResult"))));
expectReject("MS13-MS17 derivan orden del fin de proceso", () => validateStagedRuntimeHolderContract(mutateHarnessFunction("Invoke-ActivityConcurrencyScenarios", (block) => block.replace("HolderReleasedAfterExactPair = $ms13Pair.HolderReleasedAfterExactPair", "HolderReleasedAfterExactPair = ($ms13Pair.Holder.CompletedAtUtc -gt $ms13Pair.Waiter.CompletedAtUtc)"))));
expectReject("holder staged omite ownership PID", () => validateStagedRuntimeHolderContract(mutateHarnessFunction("Start-StagedRuntimeAdvisoryHolder", (block) => block.replace("Update-ExecuteWorkerManifest -ExecutionContext $executionContext -ProcessId $process.Id -Operation \"add\"", "OmittedExecuteWorkerManifest"))));
expectReject("par crea SQL antes del ownership try", () => validatePairedSqlLifecycleContract(mutateHarnessFunction("Invoke-AdvisoryWaitPair", (block) => block.replace("  try {\n    $holderArtifact = New-SqlFile", "  $holderArtifact = New-SqlFile"))));
expectReject("wall-clock crea fixture antes de cercar SQL", () => validatePairedSqlLifecycleContract(mutateHarnessFunction("Invoke-WallClockScenarios", (block) => block.replace("$holderArtifact = New-SqlFile", "$fixtureCreationAttempted = $true\n      New-RuntimeActivityFixture\n      $holderArtifact = New-SqlFile"))));
expectReject("cleanup de par elimina sólo waiter", () => validatePairedSqlLifecycleContract(mutateHarnessFunction("Invoke-AdvisoryWaitPair", (block) => block.replace('Remove-UnownedTransientSqlFile -State $pairResources -Role "Holder" -RunDirectory $RunDirectory', "OmittedHolderSqlCleanup"))));
expectReject("controller borra archivo aún poseído por worker", () => validatePairedSqlLifecycleContract(mutateHarnessFunction("Remove-UnownedTransientSqlFile", (block) => block.replace('@("starter", "worker")', '@("starter")'))));
expectReject("PostcheckOnly omite residuo SQL transitorio", () => validatePairedSqlLifecycleContract(mutateHarnessFunction("Invoke-PostcheckOnlyMode", (block) => block.replace("$postcheck.TransientWorkerSqlFiles -eq $manifest.ExpectedDiagnosticCounts.TransientWorkerSqlFiles", "$true"))));
expectReject("aprobación final omite residuo SQL transitorio", () => validatePairedSqlLifecycleContract(mutateHarnessFunction("Invoke-Phase06FinalPostcheck", (block) => block.replace("Assert-Condition -Condition ($postcheck.TransientWorkerSqlFiles -eq 0)", "Assert-Condition -Condition $true"))));
expectReject("New-SqlFile omite remoción transitoria", () => validateTransientSqlCreationContract(mutateHarnessFunction("New-SqlFile", (block) => block.replace("$cleanup = Invoke-TransientSqlPathCleanup -CreationState $creationState -RunDirectory $RunDirectory", "$cleanup = [pscustomobject]@{ Succeeded = $true; SecondaryErrors = @() }"))));
expectReject("New-SqlFile construye el path después del write", () => validateTransientSqlCreationContract(mutateHarnessFunction("New-SqlFile", (block) => block.replace("$path = [System.IO.Path]::GetFullPath", "$deferredPath = [System.IO.Path]::GetFullPath").replace("Write-ExternalUtf8File -Path $creationState.Path", "$path = $deferredPath\n      Write-ExternalUtf8File -Path $creationState.Path"))));
expectReject("cleanup transitorio omite postcondición de ausencia", () => validateTransientSqlCreationContract(mutateHarnessFunction("Invoke-TransientSqlPathCleanup", (block) => block.replace('Name = "TRANSIENT_SQL_PATH_ABSENT"', 'Name = "TRANSIENT_SQL_PATH_ABSENT_OMITTED"').replace("-not (Test-Path -LiteralPath $CreationState.Path)", "$true"))));
expectReject("verificación transitoria omite contenido exacto", () => validateTransientSqlCreationContract(mutateHarnessFunction("Assert-TransientSqlFileVerified", (block) => block.replace("$actualContent -ceq [string]$CreationState.CanonicalContent", "$true"))));
expectReject("verificación transitoria omite SHA-256 esperado", () => validateTransientSqlCreationContract(mutateHarnessFunction("Assert-TransientSqlFileVerified", (block) => block.replace("$actualSha256 -ceq [string]$CreationState.ExpectedSha256", "$true"))));
expectReject("remoción transitoria carece del guard disposable", () => validateTransientSqlCreationContract(mutateHarnessFunction("Invoke-TransientSqlPathCleanup", (block) => {
  const token = "      Assert-DisposableWorkerSqlPath -SqlFile ([string]$CreationState.Path) -RunDirectory $RunDirectory\n      if ($script:TransientSqlFixtureFault";
  return block.replace(token, "      if ($script:TransientSqlFixtureFault");
})));
expectReject("cleanup reemplaza el error primario", () => validateTransientSqlCreationContract(mutateHarnessFunction("New-SqlFile", (block) => block.replace("Complete-OrchestrationCleanup -PrimaryError $creationError", "Complete-OrchestrationCleanup -PrimaryError $null"))));
expectReject("fixture acepta waiter parcial", () => validateTransientSqlCreationContract(mutateHarnessFunction("Assert-Db22TransientSqlCreationFixtures", (block) => block.replace("(Get-TransientWorkerSqlFileCount -RunDirectory $fixtureRoot) -eq 0) `\n      -Code \"db22_waiter_partial_file_cleanup_fixture_rejected\"", "(Get-TransientWorkerSqlFileCount -RunDirectory $fixtureRoot) -ge 0) `\n      -Code \"db22_waiter_partial_file_cleanup_fixture_rejected\""))));
expectReject("fixture limpia holder pero no waiter", () => validateTransientSqlCreationContract(mutateHarnessFunction("Assert-Db22TransientSqlCreationFixtures", (block) => block.replace('Remove-UnownedTransientSqlFile -State $waiterState -Role "Waiter" -RunDirectory $fixtureRoot', "OmittedWaiterSqlCleanup"))));
expectReject("writer global borra publicaciones parciales", () => validateTransientSqlCreationContract(mutateHarnessFunction("Invoke-ExclusiveExternalFileWrite", (block) => block.replace("return $fileState", "Remove-Item -LiteralPath $FullPath -Force\n  return $fileState"))));
expectReject("fixture parcial no crea archivo físico", () => validateTransientSqlCreationContract(mutateHarnessFunction("Invoke-TransientSqlFixtureExclusiveWrite", (block) => block.replace("[System.IO.File]::WriteAllBytes($FullPath, $encoding.GetBytes(\"partial\"))", "$null = $FullPath"))));
expectReject("fixture ValidateOnly inicia procesos", () => validateTransientSqlCreationContract(mutateHarnessFunction("Assert-Db22TransientSqlCreationFixtures", (block) => block.replace("$fixtureError = $null", "$fixtureError = $null\n  $forbidden = [System.Diagnostics.ProcessStartInfo]::new()"))));
expectReject("MS21 cuenta observación sin readiness independiente", () => validateAdvisoryHolderReadinessContract(mutateHarnessFunction("Invoke-AdvisoryWaitPair", (block) => block.replace("if ($holderReadiness.Satisfied -and $sameHolderObservedInPair -and $observation.Satisfied -and", "if ($observation.Satisfied -and"))));
expectReject("wall-clock inicial comprueba sólo waiter", () => validateAdvisoryPairContract(mutateHarnessFunction("Invoke-WallClockScenarios", (block) => block.replace("Invoke-AdvisoryPairObservationProbe -Connection $Connection", "Invoke-WaiterOnlyObservationProbe -Connection $Connection"))));
expectReject("par advisory restaura sleep fijo de 800 ms", () => validateAdvisoryHolderReadinessContract(mutateHarnessFunction("Invoke-AdvisoryWaitPair", (block) => block.replace("$holderReadiness = Wait-ForExactAdvisoryHolder", "Start-Sleep -Milliseconds 800\n    $holderReadiness = Wait-ForExactAdvisoryHolder"))));
expectReject("wall-clock restaura sleep fijo de 700 ms", () => validateAdvisoryHolderReadinessContract(mutateHarnessFunction("Invoke-WallClockScenarios", (block) => block.replace("$holderReadiness = Wait-ForExactAdvisoryHolder", "Start-Sleep -Milliseconds 700\n      $holderReadiness = Wait-ForExactAdvisoryHolder"))));
expectReject("waiter genérico inicia antes de readiness", () => validateAdvisoryHolderReadinessContract(mutateHarnessFunction("Invoke-AdvisoryWaitPair", (block) => block.replace("$holderReadiness = Wait-ForExactAdvisoryHolder", "$waiter = Start-AdvisoryWaiterAfterHolderReady\n    $holderReadiness = Wait-ForExactAdvisoryHolder"))));
expectReject("readiness mira sesión pero no advisory concedido", () => validateAdvisoryHolderReadinessContract(mutateHarnessFunction("Test-ExactAdvisoryHolderEvidence", (block) => block.replace("$Evidence.HolderAdvisoryGranted -and", "$true -and"))));
expectReject("readiness mira advisory pero no cardinalidad de application_name", () => validateAdvisoryHolderReadinessContract(mutateHarnessFunction("Test-ExactAdvisoryHolderEvidence", (block) => block.replace("$Evidence.ExactHolderCount -eq 1 -and", "$true -and"))));
expectReject("par no se enlaza al holder congelado", () => validateAdvisoryHolderReadinessContract(mutateHarnessFunction("Invoke-AdvisoryWaitPair", (block) => block.replace("-ExpectedHolderBackendPid $frozenHolderBackendPid", "-ExpectedHolderBackendPid 0"))));
expectReject("wall-clock inicia waiter antes de readiness", () => validateAdvisoryHolderReadinessContract(mutateHarnessFunction("Invoke-WallClockScenarios", (block) => block.replace("$holderReadiness = Wait-ForExactAdvisoryHolder", "$waiterWorker = Start-AdvisoryWaiterAfterHolderReady\n      $holderReadiness = Wait-ForExactAdvisoryHolder"))));

expectReject("baseline omite campos MS20", () => validateMs20CandidateSetContract(mutateHarnessFunction("Get-BaselineProbeSql", (block) => block.replaceAll("ms20_candidate_count", "candidate_count_omitted").replaceAll("ms20_candidate_set_hash", "candidate_hash_omitted"))));
expectReject("candidato MS20 se descubre sólo en runtime", () => validateMs20CandidateSetContract(mutateHarnessFunction("Get-BaselineProbeSql", (block) => block.replace("$ms20CandidateSetSql = Get-Ms20CandidateSetSql", "$ms20CandidateSetSql = 'select null::uuid where false'"))));
expectReject("baseline y runtime MS20 usan predicados distintos", () => validateMs20CandidateSetContract(mutateHarnessFunction("Invoke-Ms20CandidateSetProbe", (block) => block.replace("$candidateSetSql = Get-Ms20CandidateSetSql", "$candidateSetSql = 'select profile.id from public.profiles profile where false'"))));
expectReject("selección MS20 omite orden UUID", () => validateMs20CandidateSetContract(mutateHarnessFunction("Invoke-Ms20CandidateSetProbe", (block) => block.replace("order by candidate.id", "order by random()"))));
expectReject("baseline acepta cero candidatos MS20", () => validateMs20CandidateSetContract(mutateHarnessFunction("Invoke-ReadOnlyBaseline", (block) => block.replace("Ms20CandidateCount -ge 1", "Ms20CandidateCount -ge 0"))));
expectReject("comparación MS20 acepta deriva", () => validateMs20CandidateSetContract(mutateHarnessFunction("Test-Ms20CandidateSetMatchesFrozen", (block) => block.replace("return ($State.CandidateCount", "return ($FrozenFingerprint.Ms20CandidateCount"))));
expectReject("evidencia probe expone candidato MS20", () => validateMs20CandidateSetContract(mutateHarnessFunction("Invoke-ReadOnlyProbeMode", (block) => block.replace('"MS20_CANDIDATE_SET|APPROVED",', '"MS20_CANDIDATE_SET|$($baseline.SelectedCandidateId)",'))));
expectReject("MS20 restaura holder con pg_sleep", () => validateAuthorityLossContract(mutateHarnessFunction("Start-StagedAuthorityLossHolder", (block) => block.replace("select 'MS20_HOLDER_LOCKED|1';", "select 'MS20_HOLDER_LOCKED|1';`nselect pg_sleep(8);"))));
expectReject("MS20 omite segunda observación tras retirar autoridad", () => validateAuthorityLossContract(mutateHarnessFunction("Invoke-AuthorityLossScenario", (block) => block.replace("$postRemovalObservation = Wait-ForObserverCondition", "$postRemovalObservation = OmittedPostRemovalObservation"))));
expectReject("MS20 libera holder antes de confirmar retiro", () => validateAuthorityLossContract(mutateHarnessFunction("Invoke-AuthorityLossScenario", (block) => block.replace("$stageBRequest = Send-StagedInstallationHolderStage -Worker $holder -Stage \"B\"", "$prematureStageBRequest = Send-StagedInstallationHolderStage -Worker $holder -Stage \"B\"`n    $stageBRequest = $prematureStageBRequest").replace("$removeSql = @\"", "$stageBRequest = Send-StagedInstallationHolderStage -Worker $holder -Stage \"B\"`n    $removeSql = @\""))));
expectReject("MS20 hardcodea retiro antes de release", () => validateAuthorityLossContract(mutateHarnessFunction("Invoke-AuthorityLossScenario", (block) => block.replace("TemporaryAssignmentRemovalCommitted = $assignmentRemovalCommitted", "TemporaryAssignmentRemovedBeforeRelease = $true"))));
expectReject("MS20 omite ausencia de asignación temporal", () => validateAuthorityLossContract(mutateHarnessFunction("Invoke-AuthorityLossScenario", (block) => block.replace("-TemporaryAssignmentId $assignmentId -RequireTemporaryAssignmentAbsent", "-TemporaryAssignmentId $assignmentId"))));
expectReject("MS20 acepta 42501 sin verificar cero periodos y auditoría", () => validateAuthorityLossContract(mutateHarnessFunction("Invoke-AuthorityLossScenario", (block) => block.replace("$post20 = Assert-NoRuntimeResidue", "$post20 = OmittedRuntimeResidueCheck"))));
expectReject("0011 cambia el lock_timeout local inmutable", () => validateInstallationTimingContract(harness, migration.replace("set local lock_timeout = '5s';", "set local lock_timeout = '6s';")));
expectReject("0011 cambia el statement_timeout local inmutable", () => validateInstallationTimingContract(harness, migration.replace("set local statement_timeout = '120s';", "set local statement_timeout = '121s';")));
expectReject("presupuesto de instalación consume el intervalo de seguridad", () => validateInstallationTimingContract(harness.replace("$script:InstallationSafetyIntervalMilliseconds = 1000", "$script:InstallationSafetyIntervalMilliseconds = 1500"), migration));
expectReject("timeout de proceso colapsa al lock_timeout", () => validateInstallationTimingContract(harness.replace("$script:InstallationMigrationCompletionTimeoutMilliseconds = 180000", "$script:InstallationMigrationCompletionTimeoutMilliseconds = 5000"), migration));
expectReject("timeout de proceso no supera statement_timeout", () => validateInstallationTimingContract(harness.replace("$script:InstallationMigrationCompletionTimeoutMilliseconds = 180000", "$script:InstallationMigrationCompletionTimeoutMilliseconds = 120000"), migration));
expectReject("PHASE_02 restaura pg_sleep(12)", () => validateStagedInstallationHolder(mutateHarnessFunction("Start-StagedInstallationHolder", (block) => block.replace("INSTALL_ACTIVITY_UPDATED|'", "INSTALL_ACTIVITY_UPDATED|' || pg_sleep(12)::text || '"))));
expectReject("holder usa un retraso fijo igual al lock_timeout", () => validateStagedInstallationHolder(mutateHarnessFunction("Start-StagedInstallationHolder", (block) => block.replace("INSTALL_ACTIVITY_UPDATED|'", "INSTALL_ACTIVITY_UPDATED|' || pg_sleep(5)::text || '"))));
expectReject("PHASE_02 usa lock_timeout como timeout del proceso", () => validateInstallation(mutateHarnessFunction("Invoke-Phase02InstallationMatrix", (block) => block.replace("-TimeoutMilliseconds $script:InstallationMigrationCompletionTimeoutMilliseconds", "-TimeoutMilliseconds $script:InstallationMigrationLockTimeoutMilliseconds"))));
expectReject("PHASE_02 omite la segunda etapa controlada", () => validateInstallation(mutateHarnessFunction("Invoke-Phase02InstallationMatrix", (block) => block.replace('Send-StagedInstallationHolderStage -Worker $holder -Stage "B"', "OmittedControllerDrivenStageB"))));
expectReject("holder confirma antes de observar la espera", () => requireInOrder("STAGE_B_SENT\nWAIT_DIRECTION_OBSERVED", ["WAIT_DIRECTION_OBSERVED", "STAGE_B_SENT"], "Stage B no puede preceder la observación"));
expectReject("observer no exige ShareRowExclusiveLock exacto", () => validatePersistentInstallationObserver(mutateHarnessFunction("Get-InstallationObserverSql", (block) => block.replaceAll("lock.mode = 'ShareRowExclusiveLock'", "lock.mode = lock.mode"))));
expectReject("observer omite RowExclusiveLock concedido al holder", () => validatePersistentInstallationObserver(mutateHarnessFunction("Get-InstallationObserverSql", (block) => block.replaceAll("lock.mode = 'RowExclusiveLock'", "lock.mode = lock.mode"))));
expectReject("observer omite la frontera de academic_periods", () => validatePersistentInstallationObserver(mutateHarnessFunction("Get-InstallationObserverSql", (block) => block.replaceAll("lock.mode = 'AccessExclusiveLock'", "lock.mode = lock.mode"))));
expectReject("observer persistente pierde sólo lectura", () => validatePersistentInstallationObserver(mutateHarnessFunction("New-StagedPsqlStartInfo", (block) => block.replace("default_transaction_read_only=on", "default_transaction_read_write=on"))));
expectReject("observación vuelve a abrir conexiones por sondeo", () => validateInstallation(mutateHarnessFunction("Invoke-Phase02InstallationMatrix", (block) => block.replace("Wait-ForInstallationWaitDirection -Observer $observer", "Invoke-PsqlSql -Connection $Connection -PsqlPath $PsqlPath -Sql 'select 1'; Wait-ForInstallationWaitDirection -Observer $observer"))));
expectReject("solicitud del observer omite timestamp monotonic", () => validatePersistentInstallationObserver(mutateHarnessFunction("Send-PersistentInstallationObserverCommand", (block) => block.replace("$sentMonotonicTimestamp = Get-MonotonicTimestamp", "$sentMonotonicTimestamp = 0"))));
expectReject("observer no comprueba deadline despues de leer", () => validatePersistentInstallationObserver(mutateHarnessFunction("Wait-PersistentInstallationObserverResponse", (block) => block.replace('    Assert-HardMonotonicDeadline -ElapsedMilliseconds $commandElapsedMilliseconds -TimeoutMilliseconds $TimeoutMilliseconds -FailureCode "installation_observer_command_timeout"', "    # deadline posterior a lectura omitido"))));
expectReject("observer retorna marcador sin deadline posterior al match", () => validatePersistentInstallationObserver(mutateHarnessFunction("Wait-PersistentInstallationObserverResponse", (block) => block.replace('      Assert-HardMonotonicDeadline -ElapsedMilliseconds $acceptedElapsedMilliseconds -TimeoutMilliseconds $TimeoutMilliseconds -FailureCode "installation_observer_late_response_rejected"', "      # deadline posterior al match omitido"))));
expectReject("observer usa solo el deadline general de 30000 ms", () => validatePersistentInstallationObserver(mutateHarnessFunction("Wait-ForInstallationWaitDirection", (block) => block.replace('$response.CommandElapsedMilliseconds -ge 0 -and $response.CommandElapsedMilliseconds -le $commandTimeout', '$stopwatch.ElapsedMilliseconds -lt $script:InstallationWaitStartDeadlineMilliseconds'))));
expectReject("parser acepta marcador wait-direction antiguo de tres campos", () => validatePersistentInstallationObserver(mutateHarnessFunction("ConvertFrom-InstallationWaitDirectionMarker", (block) => block.replace("$parts.Count -eq 5", "$parts.Count -eq 3"))));
expectReject("observer omite lock-query-start epoch", () => validatePersistentInstallationObserver(mutateHarnessFunction("Get-InstallationObserverSql", (block) => block.replaceAll("lock_query_start_epoch_ms", "lock_query_start_epoch_omitted"))));
expectReject("observer omite observation epoch", () => validatePersistentInstallationObserver(mutateHarnessFunction("Get-InstallationObserverSql", (block) => block.replaceAll("observation_epoch_ms", "observation_epoch_omitted"))));
expectReject("parser acepta espera sin consistencia de reloj servidor", () => validatePersistentInstallationObserver(mutateHarnessFunction("ConvertFrom-InstallationWaitDirectionMarker", (block) => block.replace("$script:InstallationServerClockRoundingToleranceMilliseconds", "[double]::PositiveInfinity"))));
expectReject("parser acepta marcador COMMIT antiguo de dos campos", () => validatePersistentInstallationObserver(mutateHarnessFunction("ConvertFrom-InstallationHolderCommitMarker", (block) => block.replace("$parts.Count -eq 3", "$parts.Count -eq 2"))));
expectReject("timestamp del holder se captura antes de COMMIT", () => validateStagedInstallationHolder(mutateHarnessFunction("Start-StagedInstallationHolder", (block) => block.replace("commit;\nselect 'INSTALL_HOLDER_COMMITTED", "select 'INSTALL_HOLDER_COMMITTED_PRECOMMIT|1|0';\ncommit;\nselect 'INSTALL_HOLDER_COMMITTED"))));
expectReject("etapa holder omite timestamp monotonic", () => validateStagedInstallationHolder(mutateHarnessFunction("Send-StagedInstallationHolderStage", (block) => block.replace("$sentMonotonicTimestamp = Get-MonotonicTimestamp", "$sentMonotonicTimestamp = 0"))));
expectReject("holder no comprueba deadline despues de leer", () => validateStagedInstallationHolder(mutateHarnessFunction("Wait-StagedInstallationHolderMarker", (block) => block.replace('    Assert-HardMonotonicDeadline -ElapsedMilliseconds $commandElapsedMilliseconds -TimeoutMilliseconds $TimeoutMilliseconds -FailureCode "staged_worker_marker_timeout"', "    # deadline posterior a lectura omitido"))));
expectReject("holder retorna marcador tardio", () => validateStagedInstallationHolder(mutateHarnessFunction("Wait-StagedInstallationHolderMarker", (block) => block.replace('      Assert-HardMonotonicDeadline -ElapsedMilliseconds $acceptedElapsedMilliseconds -TimeoutMilliseconds $TimeoutMilliseconds -FailureCode "staged_worker_late_marker_rejected"', "      # deadline posterior al match omitido"))));
expectReject("formula estructural mezcla muestra server y stopwatch controller", () => validatePersistentInstallationObserver(mutateHarnessFunction("Get-ServerClockStructuralTiming", (block) => block.replace('$elapsed = $CommitMarkerEpochMilliseconds - $Observation.LockQueryStartEpochMilliseconds', '$elapsed = $Observation.ServerWaitAgeMilliseconds + $Observation.CommandElapsedMilliseconds'))));
expectReject("formula estructural omite transporte de respuesta", () => validatePersistentInstallationObserver(mutateHarnessFunction("Get-ServerClockStructuralTiming", (block) => block.replace('$elapsed = $CommitMarkerEpochMilliseconds - $Observation.LockQueryStartEpochMilliseconds', '$elapsed = $Observation.ObservationEpochMilliseconds - $Observation.LockQueryStartEpochMilliseconds'))));
expectReject("delta servidor mayor de 4000 se acepta", () => validatePersistentInstallationObserver(mutateHarnessFunction("Get-ServerClockStructuralTiming", (block) => block.replace('WithinBudget = ($elapsed -le ($script:InstallationMigrationLockTimeoutMilliseconds - $script:InstallationSafetyIntervalMilliseconds))', 'WithinBudget = $true'))));
expectReject("epochs crudos entran a evidencia agregada", () => validateInstallation(mutateHarnessFunction("Invoke-Phase02InstallationMatrix", (block) => block.replace('HolderCommitMarkerPresent = ($commitLiveMarker.Value -ceq "1")', 'HolderCommitMarkerPresent = ($commitLiveMarker.Value -ceq "1")\n      CommitMarkerEpochMilliseconds = $commitLiveMarker.ServerEpochMilliseconds'))));
expectReject("deadline medido se reemplaza por booleano", () => validateInstallation(mutateHarnessFunction("Invoke-Phase02InstallationMatrix", (block) => block.replace('WaitObservedWithinInstallationDeadline = ($installationObservation.ControllerObservationElapsedMilliseconds -lt $script:InstallationWaitStartDeadlineMilliseconds)', 'WaitObservedWithinInstallationDeadline = $installationObservation.WaitObserved'))));
expectReject("timeout de migración se acepta como rechazo esperado", () => validateInstallation(mutateHarnessFunction("Invoke-Phase02InstallationMatrix", (block) => block.replace("Assert-PsqlApproved -Result $migrationResult", 'Assert-ExpectedSqlState -Result $migrationResult -SqlState "55P03"\n    Assert-PsqlApproved -Result $migrationResult'))));
expectReject("éxito depende de duración total menor a 5s", () => validateInstallation(mutateHarnessFunction("Invoke-Phase02InstallationMatrix", (block) => block.replace("ServerClockStructuralWaitThroughCommitWithinBudget = $serverClockStructuralWaitThroughCommitWithinBudget", "MigrationCompletedInsideImmutableLockBudget = ($migrationResult.ElapsedMilliseconds -lt $script:InstallationMigrationLockTimeoutMilliseconds)"))));
expectReject("orden transaccional se infiere de salida de procesos", () => validateInstallation(mutateHarnessFunction("Invoke-Phase02InstallationMatrix", (block) => block.replace("TransactionMarkerOrderObserved = (Test-TransactionMarkerOrdering", "MigrationCompletedAfterHolder = ($migrationResult.CompletedAtUtc -gt $holderResult.CompletedAtUtc); TransactionMarkerOrderObserved = (Test-TransactionMarkerOrdering"))));
expectReject("MS05 hardcodea el aislamiento observado", () => validateInstallation(mutateHarnessFunction("Invoke-Phase02InstallationMatrix", (block) => block.replace('SameProcessDefaultIsolationWasRepeatableRead = ($migrationDefaultIsolation -ceq "repeatable read")', 'SameProcessDefaultIsolationWasRepeatableRead = $true'))));
expectReject("MS06 hardcodea el aislamiento observado", () => validateRollback(mutateHarnessFunction("Invoke-Phase03RollbackMatrix", (block) => block.replace('SuccessfulSameProcessDefaultIsolationWasRepeatableRead = ($successfulRollbackDefaultIsolation -ceq "repeatable read")', 'SuccessfulSameProcessDefaultIsolationWasRepeatableRead = $true'))));
expectReject("falta el marcador de aislamiento en migración", () => validateInstallation(mutateHarnessFunction("Invoke-Phase02InstallationMatrix", (block) => block.replace(" -EmitSessionIsolationMarker", ""))));
expectReject("falta el marcador de archivo protegido completado", () => validateInstallation(mutateHarnessFunction("Invoke-Phase02InstallationMatrix", (block) => block.replace(" -EmitRepositoryFileCompletedMarker", ""))));
expectReject("marcador de aislamiento no usa la constante fija", () => validateSameProcessIsolationMarker(mutateHarnessFunction("New-PsqlStartInfo", (block) => block.replace("Quote-ProcessArgument -Value $script:SessionIsolationMarkerSql", 'Quote-ProcessArgument -Value "select 1"'))));
expectReject("marcador de aislamiento queda después de -f", () => validateSameProcessIsolationMarker(mutateHarnessFunction("New-PsqlStartInfo", (block) => block.replace('  if ($EmitSessionIsolationMarker) {\n    $info.Arguments += " -c " + (Quote-ProcessArgument -Value $script:SessionIsolationMarkerSql)\n  }\n  $info.Arguments += " -f " + (Quote-ProcessArgument -Value $SqlFile)', '  $info.Arguments += " -f " + (Quote-ProcessArgument -Value $SqlFile)\n  if ($EmitSessionIsolationMarker) {\n    $info.Arguments += " -c " + (Quote-ProcessArgument -Value $script:SessionIsolationMarkerSql)\n  }'))));
expectReject("parser acepta marcador por substring", () => validateSameProcessIsolationMarker(mutateHarnessFunction("Get-ExactSessionDefaultIsolation", (block) => block.replace('$lines[0] -ceq "SESSION_DEFAULT_ISOLATION|repeatable read"', '$lines[0] -like "*repeatable read*"'))));
expectReject("parser acepta valor de aislamiento inesperado", () => validateSameProcessIsolationMarker(mutateHarnessFunction("Get-ExactSessionDefaultIsolation", (block) => block.replace("SESSION_DEFAULT_ISOLATION|repeatable read", "SESSION_DEFAULT_ISOLATION|serializable"))));
expectReject("SQL protegido se copia a un wrapper", () => validateSameProcessIsolationMarker(mutateHarnessFunction("Invoke-ExactRepositorySqlFile", (block) => block.replace("-SqlFile $RepositorySqlFile", '-SqlFile (New-SqlFile -RunDirectory $RunDirectory -Label "wrapper" -Sql $RepositorySqlFile)'))));
expectReject("SQL protegido se modifica para anteponer el marcador", () => validateSameProcessIsolationMarker(mutateHarnessFunction("Invoke-ExactRepositorySqlFileResult", (block) => block.replace("-SqlFile $RepositorySqlFile", '-SqlFile ($RepositorySqlFile + ".modified")'))));
expectReject("MS05 acepta éxito sin POST0011 exacto", () => validateInstallation(mutateHarnessFunction("Invoke-Phase02InstallationMatrix", (block) => block.replaceAll("ExactPost0011Postcondition", "OmittedPost0011Postcondition"))));
expectReject("MS06 acepta éxito sin POST0010 exacto", () => validateRollback(mutateHarnessFunction("Invoke-Phase03RollbackMatrix", (block) => block.replaceAll("ReadCommittedPinRestoredPost0010", "OmittedPost0010Fingerprint"))));
expectReject("MS01 sin lectura posterior", () => validateStagedInstallationHolder(harness.replace("select 'INSTALL_PERIOD_READ|'", "select 'REMOVED_PERIOD_READ|'")));
expectReject("MS06 sin 55P03", () => validateRollback(mutateHarnessFunction("Invoke-Phase03RollbackMatrix", (block) => block.replace('SqlState "55P03"', 'SqlState "00000"'))));
expectReject("MS06 restaura pg_sleep(8)", () => validateRollback(mutateHarnessFunction("Invoke-Phase03RollbackMatrix", (block) => block.replace("  $holderArtifact = New-SqlFile", "  select pg_sleep(8);\n  $holderArtifact = New-SqlFile"))));
expectReject("MS06 usa un sleep más largo", () => validateRollback(mutateHarnessFunction("Invoke-Phase03RollbackMatrix", (block) => block.replace("  $holderArtifact = New-SqlFile", "  select pg_sleep(30);\n  $holderArtifact = New-SqlFile"))));
expectReject("MS06 usa Start-Sleep como evidencia", () => validateRollback(mutateHarnessFunction("Invoke-Phase03RollbackMatrix", (block) => block.replace("  $holderArtifact = New-SqlFile", "  Start-Sleep -Seconds 8\n  $holderArtifact = New-SqlFile"))));
expectReject("MS06 inicia contención antes del marcador", () => validateRollback(mutateHarnessFunction("Invoke-Phase03RollbackMatrix", (block) => block.replace("$holderReadyMarker = Wait-StagedRollbackRelationHolderMarker", "$holderReadyMarker = OmittedRollbackReadyMarker"))));
expectReject("MS06 inicia contención antes del lock exacto", () => validateRollback(mutateHarnessFunction("Invoke-Phase03RollbackMatrix", (block) => block.replace("$holderReadiness = Wait-ForExactRollbackRelationHolder", "$holderReadiness = OmittedExactRollbackRelationHolder"))));
expectReject("readiness MS06 omite pg_locks", () => validateRollback(mutateHarnessFunction("Get-RollbackRelationHolderObservationSql", (block) => block.replaceAll("pg_catalog.pg_locks", "pg_catalog.pg_stat_activity"))));
expectReject("readiness MS06 omite sesión exacta", () => validateRollback(mutateHarnessFunction("Get-RollbackRelationHolderObservationSql", (block) => block.replaceAll("pg_catalog.pg_stat_activity", "pg_catalog.pg_locks"))));
expectReject("readiness MS06 omite idle in transaction", () => validateRollback(mutateHarnessFunction("Get-RollbackRelationHolderObservationSql", (block) => block.replace("state = 'idle in transaction'", "state is not null"))));
expectReject("readiness MS06 no congela backend", () => validateRollback(mutateHarnessFunction("Test-ExactRollbackRelationHolderEvidence", (block) => block.replace("($ExpectedBackendPid -eq 0 -or $Evidence.InternalHolderBackendPid -eq $ExpectedBackendPid)", "$true"))));
expectReject("MS06 libera al arrancar contención", () => validateRollback(mutateHarnessFunction("Invoke-Phase03RollbackMatrix", (block) => block.replace("    $contendedRollbackStartCount++", "    $contendedRollbackStartCount++\n    Send-StagedRollbackRelationHolderStage -Worker $holder -Stage \"B\""))));
expectReject("MS06 libera antes de 55P03", () => validateRollback(mutateHarnessFunction("Invoke-Phase03RollbackMatrix", (block) => block.replace("    Assert-ExpectedSqlState -Result $contended", "    Send-StagedRollbackRelationHolderStage -Worker $holder -Stage \"B\"\n    Assert-ExpectedSqlState -Result $contended"))));
expectReject("MS06 acepta éxito contendido", () => validateRollback(mutateHarnessFunction("Invoke-Phase03RollbackMatrix", (block) => block.replaceAll("rollback_contended_attempt_unexpected_success", "rollback_contended_attempt_accepted_success"))));
expectReject("MS06 acepta 40P01", () => validateRollback(mutateHarnessFunction("Invoke-Phase03RollbackMatrix", (block) => block.replace("$contendedAttemptHadNoDeadlock = -not", "$contendedAttemptHadNoDeadlock ="))));
expectReject("MS06 acepta timeout de worker", () => validateRollback(mutateHarnessFunction("Invoke-Phase03RollbackMatrix", (block) => block.replace("Assert-Condition -Condition (-not $contended.TimedOut) -Code \"rollback_contended_attempt_unexpected_timeout\"", "Assert-Condition -Condition $true -Code \"rollback_contended_attempt_unexpected_timeout\""))));
expectReject("MS06 omite observación post-55P03", () => validateRollback(mutateHarnessFunction("Invoke-Phase03RollbackMatrix", (block) => block.replace("$holderPostRejection = Wait-ForExactRollbackRelationHolder", "$holderPostRejection = OmittedPostRejectionHolderObservation"))));
expectReject("MS06 acepta PID cambiado", () => validateRollback(mutateHarnessFunction("Test-ExactRollbackRelationHolderEvidence", (block) => block.replace("($ExpectedBackendPid -eq 0 -or $Evidence.InternalHolderBackendPid -eq $ExpectedBackendPid)", "$true"))));
expectReject("MS06 acepta lock perdido", () => validateRollback(mutateHarnessFunction("Test-ExactRollbackRelationHolderEvidence", (block) => block.replace("$Evidence.ExactRelationLockCount -eq 1", "$true"))));
expectReject("Stage B emite marcador antes de rollback", () => validateRollback(mutateHarnessFunction("Start-StagedRuntimeAdvisoryHolder", (block) => block.replace("$stageB = \"rollback;`nselect '$ReleaseMarker|1';\"", "$stageB = \"select '$ReleaseMarker|1';`nrollback;\""))));
expectReject("MS06 acepta ready marker tardío", () => validateRollback(mutateHarnessFunction("Wait-StagedRuntimeAdvisoryHolderMarker", (block) => block.replaceAll("staged_runtime_holder_marker_late_response_rejected", "staged_runtime_holder_marker_late_response_accepted"))));
expectReject("MS06 acepta release marker tardío", () => validateRollback(mutateHarnessFunction("Wait-StagedRollbackRelationHolderMarker", (block) => block.replace("Wait-StagedRuntimeAdvisoryHolderMarker", "OmittedHardDeadlineMarkerWait"))));
expectReject("MS06 ejecuta rollback exitoso antes de cleanup", () => validateRollback(mutateHarnessFunction("Invoke-Phase03RollbackMatrix", (block) => block.replace("Assert-Condition -Condition $holderCleanupComplete -Code \"successful_rollback_before_holder_cleanup_rejected\"", "Assert-Condition -Condition $true -Code \"successful_rollback_before_holder_cleanup_rejected\""))));
expectReject("MS06 aprueba con residuo", () => validateRollback(mutateHarnessFunction("Invoke-Phase03RollbackMatrix", (block) => block.replaceAll("ZeroWorkerLockAndSqlResidue", "OmittedZeroWorkerLockAndSqlResidue"))));
expectReject("MS10 sólo lectura", () => {
  const block = extractFunction(harness, "Invoke-IsolationScenarios");
  const weakened = block
    .replace("correct_admin_academic_period", "list_admin_academic_periods")
    .replace("update public.activities", "select * from public.activities")
    .replace("publish_activity", "get_academic_period_for_date");
  validateRuntimeSemantics(harness.replace(block, weakened));
});
expectReject("huella de periodos parcial", () => validateFingerprint(harness.replace("'updated_at', period.updated_at", "'legacy', period.code")));
expectReject("huella con helper inexistente", () => validateFingerprint(mutateFingerprintSql((block) => block.replaceAll("public.acquire_sem01_calendar_lock_0011()", "public.lock_activity_semester_domain_0011()"))));
expectReject("huella sin acquire_sem01", () => validateFingerprint(mutateFingerprintSql((block) => block.replaceAll("public.acquire_sem01_calendar_lock_0011()", "public.omitted_calendar_lock_helper()"))));
expectReject("huella sin listado administrativo", () => validateFingerprint(mutateFingerprintSql((block) => block.replaceAll("public.list_admin_academic_periods(integer,integer)", "public.omitted_admin_list(integer,integer)"))));
expectReject("huella sin helper privado", () => validateFingerprint(mutateFingerprintSql((block) => block.replace("('public.normalize_sem01_reason_0011(text)')", "('public.omitted_private_helper(text)')"))));
expectReject("huella sin trigger audit update/delete", () => validateFingerprint(mutateFingerprintSql((block) => block.replaceAll("academic_period_audit_events_guard_update_delete", "omitted_audit_update_delete"))));
expectReject("huella sin trigger audit truncate", () => validateFingerprint(mutateFingerprintSql((block) => block.replaceAll("academic_period_audit_events_guard_truncate", "omitted_audit_truncate"))));
expectReject("huella sin constraints de auditoría", () => validateFingerprint(mutateFingerprintSql((block) => block.replaceAll("expected_audit_constraints", "omitted_audit_constraints"))));
expectReject("huella sin constraints exactas de actividades", () => validateFingerprint(mutateFingerprintSql((block) => block.replace("select constraint_name, constraint_definition from expected_activities_constraints", "select constraint_name from expected_activities_constraints"))));
expectReject("huella sin definiciones exactas de periodos", () => validateFingerprint(mutateFingerprintSql((block) => block.replace("select constraint_name, constraint_definition from expected_period_constraints_post0011", "select constraint_name from expected_period_constraints_post0011"))));
expectReject("huella sin inventario exacto de índices", () => validateFingerprint(mutateFingerprintSql((block) => block.replaceAll("expected_period_indexes_post0011", "omitted_period_indexes_post0011"))));
expectReject("huella sin trigger preexistente de activities", () => validateFingerprint(mutateFingerprintSql((block) => block.replaceAll("enforce_activity_writer_integrity_b2a", "omitted_activity_writer_integrity"))));
expectReject("huella sin flags RLS", () => validateFingerprint(mutateFingerprintSql((block) => block.replaceAll("relforcerowsecurity", "omitted_force_rls"))));
expectReject("ACL permite mutación service_role en periodos", () => validateFingerprint(mutateFingerprintSql((block) => block.replace("values ('authenticated','SELECT',false), ('service_role','SELECT',false)", "values ('authenticated','SELECT',false), ('service_role','UPDATE',false)"))));
expectReject("ACL permite mutación authenticated en periodos", () => validateFingerprint(mutateFingerprintSql((block) => block.replace("values ('authenticated','SELECT',false), ('service_role','SELECT',false)", "values ('authenticated','UPDATE',false), ('service_role','SELECT',false)"))));
expectReject("ACL concede acceso directo a auditoría", () => validateFingerprint(mutateFingerprintSql((block) => block.replace("not exists (select 1 from table_acl_rows where relname = 'academic_period_audit_events')", "exists (select 1 from table_acl_rows where relname = 'academic_period_audit_events')"))));
expectReject("ACL omite grants delegables noowner", () => validateFingerprint(mutateFingerprintSql((block) => block.replace("where grantee <> proowner", "where grantee <> proowner and not is_grantable"))));
expectReject("ACL administrativa con grant option", () => validateRoutineAclExactFixtures(mutateFingerprintSql((block) => block.replace("('public.create_admin_academic_period(text,date,date,boolean)', true, 'authenticated', 'EXECUTE', false)", "('public.create_admin_academic_period(text,date,date,boolean)', true, 'authenticated', 'EXECUTE', true)"))));
expectReject("ACL administrativa para service_role", () => validateRoutineAclExactFixtures(mutateFingerprintSql((block) => block.replace("('public.create_admin_academic_period(text,date,date,boolean)', true, 'authenticated', 'EXECUTE', false)", "('public.create_admin_academic_period(text,date,date,boolean)', true, 'service_role', 'EXECUTE', false)"))));
expectReject("ACL de helper privado para service_role", () => validateRoutineAclExactFixtures(mutateFingerprintSql((block) => block.replace("), expected_nonowner_acl_post0010", "    ,('public.normalize_sem01_reason_0011(text)', true, 'service_role', 'EXECUTE', true)\n), expected_nonowner_acl_post0010"))));
expectReject("huella sin contrato exacto de políticas", () => validateFingerprint(mutateFingerprintSql((block) => block.replaceAll("expected_period_policy", "omitted_period_policy"))));
expectReject("seguridad de tablas inferida sólo por banderas", () => validateFingerprint(mutateFingerprintSql((block) => block.replace("(table_acl_contract_valid and rls_contract_valid and policy_contract_valid) as table_security_valid", "rls_contract_valid as table_security_valid"))));
expectReject("normalización de funciones colapsa whitespace", () => validateFingerprint(mutateFingerprintSql((block) => block.replace("replace(replace(pg_catalog.pg_get_functiondef(procedure_info.oid), E'\\r\\n', E'\\n'), E'\\r', E'\\n')", "regexp_replace(pg_catalog.pg_get_functiondef(procedure_info.oid), E'\\\\s+', ' ', 'g')"))));
expectReject("completitud inferida sólo por hash", () => validateFingerprint(mutateFingerprintSql((block) => block.replaceAll("function_inventory_valid", "omitted_function_inventory_valid"))));
expectReject("aprobación final con rechazo inmutable", () => validateFingerprint(harness.replace("final_rejected_evidence_rejected", "final_rejected_evidence_ignored")));
expectReject("aprobación final omite publicación previa", () => validateFingerprint(mutateHarnessFunction("Invoke-Phase06FinalPostcheck", (block) => block.replace("Publish-ApprovedEvidencePair", "OmittedApprovedEvidencePublisher"))));
expectReject("aprobación final persiste antes de validar", () => validateFingerprint(mutateHarnessFunction("Invoke-Phase06FinalPostcheck", (block) => block.replace("  [void](Assert-ManifestRecord -Manifest $terminalManifest", "  Write-Manifest -Paths $Paths -Manifest $terminalManifest\n  [void](Assert-ManifestRecord -Manifest $terminalManifest"))));
expectReject("aprobación usa hash esperado y no archivo final", () => validateFingerprint(mutateHarnessFunction("Invoke-Phase06FinalPostcheck", (block) => block.replace("$actualApprovedHash = Get-Sha256 -Path $Paths.Evidence", "$actualApprovedHash = $expectedApprovedHash"))));
expectReject("rechazo publica manifiesto antes de validación terminal", () => validateManifestStateMachine(mutateHarnessFunction("Complete-RejectedManifest", (block) => block.replace("  [void](Assert-ManifestRecord -Manifest $terminalManifest", "  Write-Manifest -Paths $Paths -Manifest $terminalManifest\n  [void](Assert-ManifestRecord -Manifest $terminalManifest"))));
expectReject("manifiesto no compara hashes reales", () => validateManifestStateMachine(mutateHarnessFunction("Assert-ManifestRecord", (block) => block.replaceAll("approved_evidence_actual_hash_mismatch", "approved_evidence_hash_unverified").replaceAll("rejected_evidence_actual_hash_mismatch", "rejected_evidence_hash_unverified"))));
expectReject("target por inclusión", () => validateTargetBoundary(harness.replace('$username -ceq ("postgres." + $ExpectedReference)', "$ExpectedReference -in $identityTokens"), canonicalBoundary));
expectReject("evidencia desde RequiredScenarios", () => validateExplicitApprovals(harness.replace("foreach ($result in @($ApprovedResults | Sort-Object Id))", "foreach ($scenario in $script:RequiredScenarios)"), scenarioIds));
expectReject("clasificación uniforme fail_closed", () => validateFailures(harness.replace('FailureClass $failureClass', 'FailureClass "fail_closed"')));
expectReject("clasificación externa usa $_ tras catch anidado", () => validateFailures(mutateHarnessFunction("Invoke-ExecuteMode", (block) => block.replace('$failureClass = if ($caughtError.Exception.Data.Contains', '$failureClass = if ($_.Exception.Data.Contains'))));
expectReject("PID durable sólo en PHASE_02", () => validateWorkerSourceLifecycle(mutateHarnessFunction("Start-PsqlWorker", (block) => block.replace("Update-ExecuteWorkerManifest -ExecutionContext $executionContext", "OmittedExecuteWorkerManifest"))));
expectReject("PID local y manifiesto no se comparan", () => validateWorkerSourceLifecycle(mutateHarnessFunction("Update-ExecuteWorkerManifest", (block) => block.replace("Assert-WorkerPidSetsAgree", "OmittedWorkerPidSetsAgree"))));
expectReject("escenario faltante", () => validateScenarioMap(scenarioBlock.replace(/\n[^\n]*MS24_ZERO_RESIDUE[^\n]*/, "")));
expectReject("fases runtime/reaplicación inversas", () => {
  const block = extractFunction(harness, "Invoke-ExecuteMode");
  const weakened = block
    .replace("Invoke-Phase04Reapply0011", "__SWAP__")
    .replace("Invoke-Phase05RuntimeMatrix", "Invoke-Phase04Reapply0011")
    .replace("__SWAP__", "Invoke-Phase05RuntimeMatrix");
  validatePhaseOrder(harness.replace(block, weakened));
});
expectReject("URI embebida", () => validateNoEmbeddedCredential(`${harness}\n$u='postgres://embedded';`));
expectReject("bypass destructivo", () => validateNoDestructiveBypass(`${harness}\nTRUNCATE public.activities;`));

expectReject("PostcheckOnly aprueba con actividades", () => validatePostcheckDiagnostic(mutatePostcheck((block) => block.replace('$activityCountMatches = $expectedCountsAvailable -and $postcheck.Activities -eq $manifest.ExpectedDiagnosticCounts.Activities', '$activityCountMatches = $true'))));
expectReject("PostcheckOnly aprueba con auditoría", () => validatePostcheckDiagnostic(mutatePostcheck((block) => block.replace('$auditCountMatches = $expectedCountsAvailable -and $postcheck.AuditEvents -eq $manifest.ExpectedDiagnosticCounts.AuditEvents', '$auditCountMatches = $true'))));
expectReject("PostcheckOnly aprueba con periodos fixture", () => validatePostcheckDiagnostic(mutatePostcheck((block) => block.replace('$fixtureCountMatches = $expectedCountsAvailable -and $postcheck.FixturePeriods -eq $manifest.ExpectedDiagnosticCounts.FixturePeriods', '$fixtureCountMatches = $true'))));
expectReject("PostcheckOnly aprueba con workers", () => validatePostcheckDiagnostic(mutatePostcheck((block) => block.replace('$workerCountMatches = $expectedCountsAvailable -and $postcheck.OpenWorkers -eq $manifest.ExpectedDiagnosticCounts.OpenWorkers', '$workerCountMatches = $true'))));
expectReject("PostcheckOnly aprueba con advisory lock", () => validatePostcheckDiagnostic(mutatePostcheck((block) => block.replace('$postcheck.GrantedSem01AdvisoryLocks -eq $manifest.ExpectedDiagnosticCounts.GrantedSem01AdvisoryLocks', '$true'))));
expectReject("PostcheckOnly aprueba con objetos temporales", () => validatePostcheckDiagnostic(mutatePostcheck((block) => block.replace('$temporaryCountMatches = $expectedCountsAvailable -and $postcheck.TemporaryObjects -eq $manifest.ExpectedDiagnosticCounts.TemporaryObjects', '$temporaryCountMatches = $true'))));
expectReject("PostcheckOnly vuelve a APPROVED", () => validatePostcheckDiagnostic(mutatePostcheck((block) => block.replaceAll("POSTCHECK_ONLY|CLEAN", "POSTCHECK_ONLY|APPROVED"))));
expectReject("PostcheckOnly muta RunStatus", () => validatePostcheckDiagnostic(mutatePostcheck((block) => block.replace("$lines = Get-PostcheckDiagnosticLines", '$manifest.RunStatus = "ready"\n    $lines = Get-PostcheckDiagnosticLines'))));
expectReject("mismatch aborta antes del diagnóstico", () => validatePostcheckDiagnostic(mutatePostcheck((block) => block.replace("$baselineAvailable =", 'Assert-Condition -Condition $stateMatches -Code "postcheck_state_mismatch"\n    $baselineAvailable ='))));

expectReject("PGOPTIONS transporta aislamiento multiword sin escape", () => validatePgOptionsContract(mutateHarnessFunction("New-PsqlStartInfo", (block) => block.replace("default_transaction_isolation=$encodedIsolation", "default_transaction_isolation=read committed"))));
expectReject("PGOPTIONS interpola DefaultIsolation directamente", () => validatePgOptionsContract(mutateHarnessFunction("New-PsqlStartInfo", (block) => block.replace("default_transaction_isolation=$encodedIsolation", "default_transaction_isolation=$DefaultIsolation"))));
expectReject("PGOPTIONS pierde allowlist de aislamiento", () => validatePgOptionsContract(mutateHarnessFunction("New-PsqlStartInfo", (block) => block.replace('[ValidateSet("read committed", "repeatable read")]', ""))));
expectReject("PGOPTIONS introduce comillas literales", () => validatePgOptionsContract(mutateHarnessFunction("New-PsqlStartInfo", (block) => block.replace("default_transaction_isolation=$encodedIsolation", 'default_transaction_isolation="$encodedIsolation"'))));
expectReject("PGOPTIONS omite statement_timeout", () => validatePgOptionsContract(mutateHarnessFunction("New-PsqlStartInfo", (block) => block.replace("statement_timeout=$StatementTimeoutMilliseconds", "statement_timeout_omitted"))));
expectReject("PGOPTIONS omite lock_timeout", () => validatePgOptionsContract(mutateHarnessFunction("New-PsqlStartInfo", (block) => block.replace("lock_timeout=$LockTimeoutMilliseconds", "lock_timeout_omitted"))));
expectReject("observer wall-clock no supera margen", () => validateWallClockTimingContract(harness.replace("$script:WallClockObserverTimeoutMilliseconds = 55000", "$script:WallClockObserverTimeoutMilliseconds = 45000")));
expectReject("holder wall-clock no supera observer", () => validateWallClockTimingContract(harness.replace("$script:WallClockHolderSeconds = 70", "$script:WallClockHolderSeconds = 55")));
expectReject("cruce wall-clock omite locks", () => validateRuntimeSemantics(mutateHarnessFunction("Invoke-WallClockScenarios", (block) => block.replaceAll("pg_catalog.pg_locks", "pg_catalog.pg_stat_activity"))));
expectReject("cruce wall-clock vuelve al marcador CLOCK_CROSSED", () => validateRuntimeSemantics(mutateHarnessFunction("Invoke-WallClockScenarios", (block) => block.replaceAll("CLOCK_CROSSED_WHILE_WAITING", "CLOCK_CROSSED"))));
expectReject("StartCrossed deriva del probe antiguo", () => validateRuntimeSemantics(mutateHarnessFunction("Invoke-WallClockScenarios", (block) => block.replace('$startCrossedWhileWaiterBlocked = ($combinedMarker.Count -eq 4 -and $combinedMarker[1] -eq "1" -and $combinedMarker[2] -eq "1")', '$startCrossedWhileWaiterBlocked = ($clockCrossed[1] -eq "1")'))));
expectReject("holder se espera antes del cruce combinado", () => validateRuntimeSemantics(mutateHarnessFunction("Invoke-WallClockScenarios", (block) => block.replace('Wait-ForObserverCondition -FailureCode ($Label + "_clock_crossing_not_observed") -Probe $observeClockCrossingWhileWaiting -TimeoutMilliseconds $script:WallClockObserverTimeoutMilliseconds', 'Wait-PsqlWorker -Worker $wallResources.HolderWorker\n      Wait-ForObserverCondition -FailureCode ($Label + "_clock_crossing_not_observed") -Probe $observeClockCrossingWhileWaiting -TimeoutMilliseconds $script:WallClockObserverTimeoutMilliseconds'))));
expectReject("postcheck aprobado y fallido comparten ruta", () => validateTerminalArtifactContract(mutateHarnessFunction("New-RunPaths", (block) => block.replace('FailurePostcheck = Join-Path $runDirectory "failure-postcheck.local.txt"', 'FailurePostcheck = Join-Path $runDirectory "final-postcheck.local.txt"'))));
expectReject("rechazo con postcheck fallido queda incompleto", () => validatePostcheckDiagnostic(mutateHarnessFunction("Get-TerminalArtifactClassification", (block) => block.replace('elseif ($rejectedSide -and $RunStatus -cne "rejected")', 'elseif ($rejectedSide)'))));
expectReject("publicaciones terminales ignoradas por PostcheckOnly", () => validatePostcheckDiagnostic(mutatePostcheck((block) => block.replace("$terminalArtifacts = Get-TerminalArtifactInventory -Paths $paths", '$terminalArtifacts = [pscustomobject]@{ TotalPublishingArtifacts = 0 }'))));
expectReject("PostcheckOnly permite CLEAN con publishing", () => validatePostcheckDiagnostic(mutatePostcheck((block) => block.replace("$terminalArtifacts.TotalPublishingArtifacts -eq 0 -and $provenanceMatches", "$provenanceMatches"))));
expectReject("fallo secundario reemplaza ErrorRecord", () => validateFailures(mutateHarnessFunction("Invoke-ExecuteMode", (block) => block.replace('$rejectedEvidenceResult = Invoke-SecondaryFailureOperation -Operation {', '$rejectedEvidenceResult = & {'))));
expectReject("CurrentScenario inicia en MS01", () => validateFailures(harness.replace("$script:CurrentScenario = $null", '$script:CurrentScenario = "MS01_PRE0011_ACTIVITY_RELATION_LOCK"')));
expectReject("fallo de fase hereda escenario anterior", () => validateFailures(mutateHarnessFunction("Invoke-ExecuteMode", (block) => block.replace('else { "NONE" }', 'else { "MS01_PRE0011_ACTIVITY_RELATION_LOCK" }'))));
expectReject("evidencia fallida siempre afirma postcheck", () => validateFailures(mutateHarnessFunction("Publish-RejectedEvidence", (block) => block.replace('$(if ($FailurePostcheckRecorded) { "FAILURE_POSTCHECK|RECORDED" } else { "FAILURE_POSTCHECK|NOT_RECORDED" })', '"FAILURE_POSTCHECK|RECORDED"'))));
expectReject("aprobación parcial se convierte en rechazo", () => validateManifestStateMachine(mutateHarnessFunction("Invoke-ExecuteMode", (block) => block.replace('if ($terminalSnapshotResult.Succeeded -and -not (Test-ApprovedFinalizationStarted -Inventory $terminalSnapshotResult.Value))', 'if ($terminalSnapshotResult.Succeeded)'))));

console.log("SEM-01 0011 multisession harness static contract: OK");
