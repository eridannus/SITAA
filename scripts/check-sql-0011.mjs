import assert from "node:assert/strict";
import crypto from "node:crypto";
import fs from "node:fs";
import path from "node:path";

const root = process.cwd();
const artifacts = {
  preflight: "supabase/reconciliation/0011_academic_period_administration_preflight.sql",
  migration: "supabase/migrations/0011_academic_period_administration.sql",
  verify: "supabase/reconciliation/0011_academic_period_administration_verify.sql",
  rollback: "supabase/reconciliation/0011_academic_period_administration_rollback.sql",
  testPlan: "docs/TEST_PLAN_0011.md",
};

const normalizeEol = (value) => value.replace(/\r\n?/g, "\n");
const read = (relative) => normalizeEol(
  fs.readFileSync(path.join(root, relative), "utf8"),
);
const sources = Object.fromEntries(
  Object.entries(artifacts).map(([key, relative]) => [key, read(relative)]),
);
const sqlSources = Object.fromEntries(
  Object.entries(sources).filter(([key]) => key !== "testPlan"),
);

function sha256(value) {
  return crypto.createHash("sha256").update(normalizeEol(value), "utf8").digest("hex");
}

function lineAtOffset(source, offset) {
  return source.slice(0, offset).split("\n").length;
}

function assertLexicallyBalanced(source, label) {
  let round = 0;
  let square = 0;
  let single = false;
  let lineComment = false;
  let blockComment = false;
  let dollar = null;
  for (let index = 0; index < source.length; index += 1) {
    const current = source[index];
    const next = source[index + 1];
    if (lineComment) {
      if (current === "\n") lineComment = false;
      continue;
    }
    if (blockComment) {
      if (current === "*" && next === "/") {
        blockComment = false;
        index += 1;
      }
      continue;
    }
    if (dollar) {
      if (source.startsWith(dollar, index)) {
        index += dollar.length - 1;
        dollar = null;
      }
      continue;
    }
    if (single) {
      if (current === "'" && next === "'") {
        index += 1;
        continue;
      }
      if (current === "'") single = false;
      continue;
    }
    if (current === "-" && next === "-") {
      lineComment = true;
      index += 1;
      continue;
    }
    if (current === "/" && next === "*") {
      blockComment = true;
      index += 1;
      continue;
    }
    if (current === "'") {
      single = true;
      continue;
    }
    if (current === "$") {
      const match = source.slice(index).match(/^(\$[A-Za-z_][A-Za-z0-9_]*\$|\$\$)/);
      if (match) {
        dollar = match[1];
        index += dollar.length - 1;
        continue;
      }
    }
    if (current === "(") round += 1;
    if (current === ")") round -= 1;
    if (current === "[") square += 1;
    if (current === "]") square -= 1;
    assert.ok(round >= 0, `${label}: paréntesis inesperado en línea ${lineAtOffset(source, index)}`);
    assert.ok(square >= 0, `${label}: corchete inesperado en línea ${lineAtOffset(source, index)}`);
  }
  assert.equal(round, 0, `${label}: paréntesis sin cerrar`);
  assert.equal(square, 0, `${label}: corchete sin cerrar`);
  assert.equal(single, false, `${label}: literal sin cerrar`);
  assert.equal(blockComment, false, `${label}: comentario sin cerrar`);
  assert.equal(dollar, null, `${label}: bloque dollar-quoted sin cerrar`);
}

function stripTrailingComments(source) {
  return source.replace(/--[^\n]*$/gm, "").trim().toLowerCase();
}

function extractFunction(source, functionName) {
  const pattern = new RegExp(
    `create(?:\\s+or\\s+replace)?\\s+function\\s+public\\.${functionName.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")}\\s*\\(`,
    "i",
  );
  const match = pattern.exec(source);
  assert.ok(match, `No se encontró la función public.${functionName}`);
  const start = match.index;
  const next = source.indexOf("\n$function$;", start);
  assert.ok(next > start, `No se encontró el cierre de public.${functionName}`);
  return source.slice(start, next + "\n$function$;".length);
}

function extractCreateTable(source, tableName) {
  const pattern = new RegExp(`create\\s+table\\s+public\\.${tableName}\\s*\\(`, "i");
  const match = pattern.exec(source);
  assert.ok(match, `No se encontró la tabla public.${tableName}`);
  const end = source.indexOf("\n);", match.index);
  assert.ok(end > match.index, `No se encontró el cierre de public.${tableName}`);
  return source.slice(match.index, end + "\n);".length);
}

function extractDollarBlock(source, tag) {
  const delimiter = `$${tag}$`;
  const opening = `do ${delimiter}`;
  const start = source.toLowerCase().indexOf(opening.toLowerCase());
  assert.ok(start >= 0, `No se encontró el bloque ${delimiter}`);
  const endMarker = `\n${delimiter};`;
  const end = source.indexOf(endMarker, start);
  assert.ok(end > start, `No se encontró el cierre de ${delimiter}`);
  return source.slice(start, end + endMarker.length);
}

function normalizedSql(source) {
  return source.replace(/\s+/g, " ").trim().toLowerCase();
}

function assertTransactionModePrologue(source, label) {
  assert.match(
    source,
    /^(?:\uFEFF)?(?:\s*--[^\n]*(?:\n|$))*\s*begin\s*;\s*set\s+transaction\s+isolation\s+level\s+read\s+committed\s*;\s*set\s+transaction\s+read\s+write\s*;/i,
    `${label}: debe fijar READ COMMITTED y READ WRITE inmediatamente después de BEGIN`,
  );
}

function orderedOffset(source, fragment, label) {
  const offset = normalizedSql(source).indexOf(normalizedSql(fragment));
  assert.ok(offset >= 0, `${label}: falta ${fragment}`);
  return offset;
}

function assertMigrationStructuralLockContract(source, label) {
  const advisory = orderedOffset(
    source,
    "select pg_catalog.pg_advisory_xact_lock(1397310541, 1101);",
    label,
  );
  const activities = orderedOffset(
    source,
    "lock table public.activities in share row exclusive mode;",
    label,
  );
  const periods = orderedOffset(
    source,
    "lock table public.academic_periods in access exclusive mode;",
    label,
  );
  const lockedGuard = orderedOffset(source, "do $locked_baseline_guard$", label);
  assert.ok(
    advisory < activities && activities < periods && periods < lockedGuard,
    `${label}: el orden debe ser advisory, activities, academic_periods y guarda post-lock`,
  );
}

function assertRollbackStructuralLockContract(source, label) {
  const advisory = orderedOffset(
    source,
    "select pg_catalog.pg_advisory_xact_lock(1397310541, 1101);",
    label,
  );
  const activities = orderedOffset(
    source,
    "lock table public.activities in share row exclusive mode nowait;",
    label,
  );
  const periods = orderedOffset(
    source,
    "lock table public.academic_periods in access exclusive mode nowait;",
    label,
  );
  const audit = orderedOffset(
    source,
    "lock table public.academic_period_audit_events in access exclusive mode nowait;",
    label,
  );
  const eligibility = orderedOffset(source, "do $rollback_eligibility$", label);
  assert.ok(
    advisory < activities && activities < periods && periods < audit && audit < eligibility,
    `${label}: el orden debe ser advisory, activities, academic_periods, auditoría y elegibilidad`,
  );
}

const runtimeIsolationGuard = [
  "if current_setting('transaction_isolation') <> 'read committed' then",
  "raise exception 'sitaa_sem01_read_committed_required' using errcode = '25000';",
  "end if;",
].join(" ");

function assertRuntimeIsolationGuard(functionSource, label, guardedFragments) {
  const normalized = normalizedSql(functionSource);
  const bodyMarker = "as $function$";
  const bodyStart = normalized.indexOf(bodyMarker);
  assert.ok(bodyStart >= 0, `${label}: falta el cuerpo PL/pgSQL`);
  const executableStart = normalized.indexOf(" begin ", bodyStart + bodyMarker.length);
  assert.ok(executableStart >= 0, `${label}: falta BEGIN ejecutable`);
  const executable = normalized.slice(executableStart + " begin ".length);
  assert.ok(
    executable.startsWith(runtimeIsolationGuard),
    `${label}: el guard READ COMMITTED debe ser la primera lógica ejecutable`,
  );
  const guardOffset = normalized.indexOf(runtimeIsolationGuard, executableStart);
  for (const fragment of guardedFragments) {
    const fragmentOffset = normalized.indexOf(normalizedSql(fragment), executableStart);
    assert.ok(fragmentOffset >= 0, `${label}: falta la operación protegida ${fragment}`);
    assert.ok(
      guardOffset < fragmentOffset,
      `${label}: ${fragment} no puede preceder el guard READ COMMITTED`,
    );
  }
}

const transitionPredicates = [
  "academic_period_id is not null and academic_period_id is distinct from proposed_resolution",
  "academic_period_id is not null and current_resolution is distinct from proposed_resolution",
  "status_code <> 'draft' and academic_period_id is distinct from current_resolution",
  "status_code <> 'draft' and current_resolution is distinct from proposed_resolution",
  "status_code = 'draft' and academic_period_id is null and current_resolution is not null and proposed_resolution is distinct from current_resolution",
];

function assertInitialResolverTransitionContract(source, label) {
  const normalized = normalizedSql(source);
  assert.ok(normalized.includes("current_resolution"), `${label}: falta resolución post-0010`);
  assert.ok(normalized.includes("proposed_resolution"), `${label}: falta resolución SEM-01`);
  for (const predicate of transitionPredicates) {
    assert.ok(normalized.includes(predicate), `${label}: falta transición bloqueante: ${predicate}`);
  }
  assert.equal(
    normalized.includes(
      "status_code = 'draft' and academic_period_id is null and current_resolution is null and proposed_resolution is not null",
    ),
    false,
    `${label}: la habilitación benigna NULL-a-válido no puede bloquearse`,
  );
}

function assertLockedBaselineGuardContract(source, label) {
  assert.match(source, /count\(\*\)\s+from\s+public\.academic_periods\)\s*<>\s*5/i,
    `${label}: falta cardinalidad exacta de periodos`);
  assert.match(source, /expected_period_seed[\s\S]*actual_period_seed/i,
    `${label}: falta el mapa exacto de periodos`);
  assert.match(source, /select \* from actual_period_seed except select \* from expected_period_seed[\s\S]*select \* from expected_period_seed except select \* from actual_period_seed/i,
    `${label}: el mapa de periodos debe ser bidireccional`);
  for (const periodCode of ["pilot", "2026-1", "2026-2", "2027-1", "2027-2"]) {
    assert.ok(source.includes(`'${periodCode}'`), `${label}: falta periodo canónico ${periodCode}`);
  }
  assert.match(source, /created_at[\s\S]*updated_at/i,
    `${label}: faltan timestamps exactos de la semilla`);
  assert.match(source, /8af9fc114f31320519e894770823cc1d/,
    `${label}: falta huella histórica id/código`);
  assert.match(source, /code\s*!~\s*'\^\[0-9\]\{4\}-\[12\]\$'[\s\S]*starts_on\s+is\s+null[\s\S]*ends_on\s+is\s+null/i,
    `${label}: falta integridad de periodos ordinarios`);
  assert.match(source, /daterange\(left_period\.starts_on, left_period\.ends_on, '\[\]'\)[\s\S]*&&[\s\S]*daterange\(right_period\.starts_on, right_period\.ends_on, '\[\]'\)/i,
    `${label}: falta rechazo de traslapes activos`);
  assert.match(source, /group\s+by\s+period\.starts_on[\s\S]*having\s+count\(\*\)\s*>\s*1/i,
    `${label}: falta rechazo de fronteras activas duplicadas`);
  assert.match(source, /from\s+public\.activities\s+activity/i,
    `${label}: falta releer activities después del lock`);
  assert.match(source, /get_academic_period_for_date\(activity\.start_date\)/i,
    `${label}: falta resolución post-0010`);
  assert.match(source, /sitaa_0011_locked_period_baseline_changed/,
    `${label}: falta error estable de periodos`);
  assert.match(source, /sitaa_0011_locked_activity_resolution_changed/,
    `${label}: falta error estable de actividades`);
  assertInitialResolverTransitionContract(source, label);
  assert.doesNotMatch(source, /\b(?:insert\s+into|update|delete\s+from)\s+public\.activities\b/i,
    `${label}: la guarda no puede mutar actividades`);
}

function assertFutureStartWallClockContract(source, label) {
  assert.match(source, /validation_now\s*:=\s*clock_timestamp\(\)/i,
    `${label}: falta capturar reloj de pared`);
  assert.match(source, /start_value\s+at\s+time\s+zone\s+'America\/Mexico_City'\)\s*<=\s*validation_now/i,
    `${label}: la decisión futura debe usar el reloj capturado`);
  assert.doesNotMatch(source, /\b(?:current_timestamp|transaction_timestamp)\b|\bnow\s*\(/i,
    `${label}: no puede usar tiempo de inicio de transacción`);
}

function exactVerifierCaseNumbers(source, label) {
  const caseNumbers = [...source.matchAll(/\bpg_temp\.pass\s*\(\s*(\d+)\s*,/g)]
    .map((match) => Number(match[1]));
  const expected = Array.from({ length: 51 }, (_, index) => index + 1);
  assert.equal(caseNumbers.length, 51, `${label}: deben existir exactamente 51 resultados`);
  assert.equal(new Set(caseNumbers).size, 51, `${label}: no se permiten casos duplicados`);
  assert.ok(caseNumbers.every((caseNumber) => caseNumber >= 1 && caseNumber <= 51),
    `${label}: hay un caso fuera del rango 1–51`);
  assert.deepEqual([...caseNumbers].sort((left, right) => left - right), expected,
    `${label}: los resultados deben ser exactamente 1–51`);
  return caseNumbers;
}

for (const [label, source] of Object.entries(sqlSources)) {
  assertLexicallyBalanced(source, label);
  assert.match(source, /^(?:\s*--[^\n]*\n)*\s*begin\s*;/i,
    `${label}: debe abrir transacción explícita`);
}
for (const sourceName of ["migration", "rollback", "verify"]) {
  assertTransactionModePrologue(sources[sourceName], sourceName);
}
assert.throws(
  () => assertTransactionModePrologue("begin;\nset local lock_timeout = '5s';", "migración sin pin"),
  /debe fijar READ COMMITTED y READ WRITE/,
  "La regresión negativa debe rechazar una migración con BEGIN sin pin de aislamiento",
);
assert.throws(
  () => assertTransactionModePrologue("begin;\nset local lock_timeout = '5s';", "rollback sin pin"),
  /debe fijar READ COMMITTED y READ WRITE/,
  "La regresión negativa debe rechazar un rollback con BEGIN sin pin de aislamiento",
);
assert.match(stripTrailingComments(sources.preflight), /rollback\s*;$/, "El preflight debe terminar en ROLLBACK");
assert.match(stripTrailingComments(sources.migration), /commit\s*;$/, "La migración debe terminar en COMMIT");
assert.match(stripTrailingComments(sources.verify), /rollback\s*;$/, "El verificador debe terminar en ROLLBACK");
assert.match(stripTrailingComments(sources.rollback), /commit\s*;$/, "El rollback debe terminar en COMMIT");

const immutableMigrations = new Map([
  ["0001_baseline_current_schema.sql", "62c8e53d794716b22cef2bd1008aa6704f8541cfc660825d4d8a538891274dfd"],
  ["0002_database_security_and_integrity.sql", "96329a10b93ad07a9da9d73764df78b4fba20bc0e1ba867685037ac6973fa536"],
  ["0003_fix_draft_temporal_lifecycle.sql", "059f0ee574015fc8f5a01631a7d6f894ffd429cfb3f790c9c858cd4cbe4d61e3"],
  ["0004_identity_registration_foundation.sql", "1a0ee8a54ecaa627c25b116189113ac84ef07b2f0f4ac60731dd64143cd0c6f5"],
  ["0005_fix_google_oauth_user_creation.sql", "89a7f8a9dce2df9e0466101c254a80a05493b93d7796bf772e6b46d7004663b5"],
  ["0006_structured_person_names.sql", "330dbd4d5a5fc5d508100ca09a3f4c989bd0e7a4ce4aadff2daaf4ab352db1f3"],
  ["0007_admin_account_directory_audit.sql", "967dccf8acabdd0955947cf42b97727e73072e1d5c7b0a8a2f574e126fce32d4"],
  ["0008_operational_account_barrier_identity_correction.sql", "b1b1917203d4243385daa4b85f45d17d5d75c64e9822bdf5372ff66c7b0bca9a"],
  ["0009_admin_account_lifecycle_transitions.sql", "c525998b028d5d0f8f7eed6803444b4a8e529e478c7846e8894227a65593b922"],
  ["0010_coordinated_auth_session_suspension.sql", "d6d809174c377d9a625097c12299b0e02368466256d25cee3e9a0dbc5e16cf0f"],
]);
for (const [fileName, expectedHash] of immutableMigrations) {
  const filePath = path.join(root, "supabase", "migrations", fileName);
  assert.equal(sha256(fs.readFileSync(filePath, "utf8")), expectedHash,
    `${fileName} dejó de ser inmutable`);
}
assert.equal(
  sha256(fs.readFileSync(path.join(root, "package-lock.json"), "utf8")),
  "3890939948f483c7e7fb2a949d85b8fdb10e048fceac8ea4ea0b5fa670740d47",
  "package-lock.json cambió o se añadió una dependencia",
);

const expectedSignatures = [
  "list_admin_academic_periods(integer,integer)",
  "create_admin_academic_period(text,date,date,boolean)",
  "correct_admin_academic_period(uuid,text,date,date,text)",
  "activate_admin_academic_period(uuid,text)",
  "deactivate_admin_academic_period(uuid,text)",
  "get_academic_period_for_date(date)",
  "publish_activity(uuid)",
];
for (const signature of expectedSignatures) {
  const [name] = signature.split("(");
  assert.match(sources.migration, new RegExp(`function\\s+public\\.${name}\\s*\\(`, "i"),
    `Falta ${signature} en la migración`);
  assert.ok(sources.testPlan.includes(signature), `Falta congelar ${signature} en TEST_PLAN_0011`);
}

assert.doesNotMatch(sources.migration, /function\s+public\.[a-z0-9_]*(?:delete|remove)[a-z0-9_]*academic_period/i,
  "No se permite RPC DELETE de periodos");
assert.doesNotMatch(sources.migration, /function\s+public\.[a-z0-9_]*academic_period[a-z0-9_]*(?:delete|remove)/i,
  "No se permite RPC DELETE de periodos");
assert.doesNotMatch(sources.migration, /\b(delete\s+from|truncate)\s+public\.activities\b/i,
  "0011 no puede borrar o truncar actividades");
assert.doesNotMatch(sources.migration, /\binsert\s+into\s+public\.activities\b/i,
  "0011 no puede insertar actividades");

for (const functionName of [
  "create_admin_academic_period",
  "correct_admin_academic_period",
  "activate_admin_academic_period",
  "deactivate_admin_academic_period",
]) {
  const body = extractFunction(sources.migration, functionName);
  assert.doesNotMatch(body, /\b(insert\s+into|update|delete\s+from)\s+public\.activities\b/i,
    `${functionName} no puede ejecutar DML sobre activities`);
  assert.ok(body.indexOf("is_exact_sem01_period_admin_0011") < body.indexOf("lock_and_reauthorize_sem01_admin_0011"),
    `${functionName}: la comprobación optimista debe preceder el lock`);
  assert.ok(body.indexOf("diagnose_academic_period_impact_0011") < Math.max(
    body.indexOf("insert into public.academic_periods"),
    body.indexOf("update public.academic_periods"),
  ), `${functionName}: el diagnóstico debe preceder la escritura`);
}

const preLockBaselineGuard = extractDollarBlock(sources.migration, "baseline_guard");
const lockedBaselineGuard = extractDollarBlock(sources.migration, "locked_baseline_guard");
assert.match(preLockBaselineGuard,
  /current_setting\('transaction_isolation'\)\s*<>\s*'read committed'[\s\S]*sitaa_0011_read_committed_required[\s\S]*25000/i,
  "La guarda embebida debe comprobar READ COMMITTED con error estable");
assert.match(preLockBaselineGuard,
  /current_setting\('transaction_read_only'\)\s*<>\s*'off'[\s\S]*sitaa_0011_read_write_required[\s\S]*25006/i,
  "La guarda embebida debe comprobar READ WRITE con error estable");
const rollbackShapeGuard = extractDollarBlock(sources.rollback, "rollback_shape_guard");
assert.match(rollbackShapeGuard,
  /current_setting\('transaction_isolation'\)\s*<>\s*'read committed'[\s\S]*sitaa_0011_read_committed_required[\s\S]*25000/i,
  "La guarda de rollback debe comprobar READ COMMITTED con error estable");
assert.match(rollbackShapeGuard,
  /current_setting\('transaction_read_only'\)\s*<>\s*'off'[\s\S]*sitaa_0011_read_write_required[\s\S]*25006/i,
  "La guarda de rollback debe comprobar READ WRITE con error estable");
assert.doesNotMatch(sources.verify, /sitaa_0011_read_write_required/i,
  "El error de contexto READ WRITE sólo corresponde a migración y rollback");
assertInitialResolverTransitionContract(sources.preflight, "preflight independiente");
assertInitialResolverTransitionContract(preLockBaselineGuard, "guarda embebida pre-lock");
assertLockedBaselineGuardContract(lockedBaselineGuard, "guarda autoritativa post-lock");
assertMigrationStructuralLockContract(sources.migration, "migración 0011");
assertRollbackStructuralLockContract(sources.rollback, "rollback 0011");
assert.match(sources.preflight, /sem01_resolver_resolved_draft_loss_or_switch[\s\S]*blocking/i,
  "El preflight debe exponer la pérdida o cambio de un borrador resoluble como bloqueo");

const activitiesStructuralLockOffset = sources.migration.indexOf(
  "lock table public.activities in share row exclusive mode;",
);
const lockedBaselineGuardOffset = sources.migration.indexOf("do $locked_baseline_guard$");
assert.ok(activitiesStructuralLockOffset >= 0
  && lockedBaselineGuardOffset > activitiesStructuralLockOffset,
"La guarda autoritativa debe releer activities después del lock estructural");

const inverseMigrationLockFixture = `
begin;
set transaction isolation level read committed;
set transaction read write;
select pg_catalog.pg_advisory_xact_lock(1397310541, 1101);
lock table public.academic_periods in access exclusive mode;
lock table public.activities in share row exclusive mode;
do $locked_baseline_guard$ begin null; end; $locked_baseline_guard$;`;
assert.throws(
  () => assertMigrationStructuralLockContract(inverseMigrationLockFixture, "fixture migración inversa"),
  /orden debe ser advisory, activities, academic_periods/,
  "La regresión negativa debe rechazar academic_periods antes de activities",
);
const earlyLockedGuardFixture = `
select pg_catalog.pg_advisory_xact_lock(1397310541, 1101);
do $locked_baseline_guard$ begin null; end; $locked_baseline_guard$;
lock table public.activities in share row exclusive mode;
lock table public.academic_periods in access exclusive mode;`;
assert.throws(
  () => assertMigrationStructuralLockContract(earlyLockedGuardFixture, "fixture guarda prematura"),
  /orden debe ser advisory, activities, academic_periods/,
  "La regresión negativa debe rechazar la guarda post-lock antes de ambos locks",
);
const inverseRollbackLockFixture = `
begin;
set transaction isolation level read committed;
set transaction read write;
select pg_catalog.pg_advisory_xact_lock(1397310541, 1101);
lock table public.academic_periods in access exclusive mode nowait;
lock table public.activities in share row exclusive mode nowait;
lock table public.academic_period_audit_events in access exclusive mode nowait;
do $rollback_eligibility$ begin null; end; $rollback_eligibility$;`;
assert.throws(
  () => assertRollbackStructuralLockContract(inverseRollbackLockFixture, "fixture rollback inverso"),
  /orden debe ser advisory, activities, academic_periods/,
  "La regresión negativa debe rechazar academic_periods antes de activities en rollback",
);

const narrowLockedGuardFixture = `
do $locked_baseline_guard$
begin
  if (select count(*) from public.academic_periods) <> 5
     or exists (select 1 from public.academic_periods where code = 'pilot') then
    raise exception 'sitaa_0011_locked_baseline_changed';
  end if;
end;
$locked_baseline_guard$;`;
assert.throws(
  () => assertLockedBaselineGuardContract(narrowLockedGuardFixture, "fixture post-lock estrecha"),
  /mapa exacto de periodos/,
  "La regresión negativa debe rechazar una guarda limitada a conteo y pilot",
);

const canonicalTransitionFixture = transitionPredicates.join(" or ");
assertInitialResolverTransitionContract(canonicalTransitionFixture, "fixture de transición canónica");
const omittedResolvedDraftFixture = canonicalTransitionFixture.replace(
  transitionPredicates.at(-1),
  "",
);
assert.throws(
  () => assertInitialResolverTransitionContract(
    omittedResolvedDraftFixture,
    "fixture sin borrador resoluble",
  ),
  /falta transición bloqueante/,
  "La regresión negativa debe rechazar la omisión de pérdida/cambio del borrador resoluble",
);

const lockHelper = extractFunction(sources.migration, "lock_and_reauthorize_sem01_admin_0011");
assertRuntimeIsolationGuard(lockHelper, "lock_and_reauthorize_sem01_admin_0011", [
  "pg_advisory_xact_lock",
  "from public.profiles",
  "is_exact_sem01_period_admin_0011",
]);
const advisoryOffset = lockHelper.indexOf("pg_advisory_xact_lock");
const academicPeriodsLockOffset = lockHelper.indexOf("lock table public.academic_periods");
const actorLockOffset = lockHelper.indexOf("from public.profiles");
const reauthorizationOffset = lockHelper.lastIndexOf("is_exact_sem01_period_admin_0011");
assert.ok(advisoryOffset >= 0 && advisoryOffset < academicPeriodsLockOffset
  && academicPeriodsLockOffset < actorLockOffset && actorLockOffset < reauthorizationOffset,
"El orden canónico es advisory, lock de academic_periods, actor y reautorización");
assert.doesNotMatch(lockHelper, /lock\s+table\s+public\.activities/i,
  "El helper runtime no puede esperar un lock de activities mientras conserva el advisory");

const activityLockHelper = extractFunction(sources.migration, "acquire_sem01_calendar_lock_0011");
assertRuntimeIsolationGuard(activityLockHelper, "acquire_sem01_calendar_lock_0011", [
  "pg_advisory_xact_lock",
]);

const publication = extractFunction(sources.migration, "publish_activity");
assertRuntimeIsolationGuard(publication, "publish_activity", [
  "is_sitaa_operational_account_active",
  "auth.uid()",
  "pg_advisory_xact_lock",
  "from public.activities",
]);
assert.ok(publication.indexOf("pg_advisory_xact_lock") < publication.indexOf("for update"),
  "publish_activity debe adquirir el advisory lock antes del row lock");
const publicationRowLockOffset = publication.indexOf("for update");
const publicationClockOffset = publication.indexOf("validation_now := clock_timestamp()");
const publicationFutureCheckOffset = publication.indexOf(
  "start_value at time zone 'America/Mexico_City') <= validation_now",
);
assert.ok(publicationRowLockOffset >= 0
  && publicationClockOffset > publicationRowLockOffset
  && publicationFutureCheckOffset > publicationClockOffset,
"publish_activity debe capturar clock_timestamp después del FOR UPDATE y antes de validar");
assertFutureStartWallClockContract(publication, "publish_activity");
assert.match(publication, /get_academic_period_for_date\(target_activity\.start_date\)/,
  "publish_activity debe resolver dentro de la transacción");
const scheduledValidator = extractFunction(sources.migration, "validate_activity_scheduled_state");
assertFutureStartWallClockContract(scheduledValidator, "validate_activity_scheduled_state");

const missingRuntimeGuardFixture = `
create function public.fixture() returns void language plpgsql as $function$
begin
  perform pg_catalog.pg_advisory_xact_lock(1397310541, 1101);
end;
$function$;`;
assert.throws(
  () => assertRuntimeIsolationGuard(missingRuntimeGuardFixture, "fixture helper sin guard", [
    "pg_advisory_xact_lock",
  ]),
  /guard READ COMMITTED debe ser la primera lógica ejecutable/,
  "La regresión negativa debe rechazar un helper sin guard de aislamiento",
);
const lateRuntimeGuardFixture = `
create function public.fixture() returns void language plpgsql as $function$
begin
  perform pg_catalog.pg_advisory_xact_lock(1397310541, 1101);
  if current_setting('transaction_isolation') <> 'read committed' then
    raise exception 'sitaa_sem01_read_committed_required' using errcode = '25000';
  end if;
end;
$function$;`;
assert.throws(
  () => assertRuntimeIsolationGuard(lateRuntimeGuardFixture, "fixture helper con guard tardío", [
    "pg_advisory_xact_lock",
  ]),
  /guard READ COMMITTED debe ser la primera lógica ejecutable/,
  "La regresión negativa debe rechazar un guard posterior al advisory",
);
const earlyPublicationReadFixture = `
create function public.fixture() returns void language plpgsql as $function$
begin
  if not public.is_sitaa_operational_account_active() then return; end if;
  select activity.* from public.activities activity for update;
  if current_setting('transaction_isolation') <> 'read committed' then
    raise exception 'sitaa_sem01_read_committed_required' using errcode = '25000';
  end if;
  perform pg_catalog.pg_advisory_xact_lock(1397310541, 1101);
end;
$function$;`;
assert.throws(
  () => assertRuntimeIsolationGuard(earlyPublicationReadFixture, "fixture publicación con lectura prematura", [
    "is_sitaa_operational_account_active",
    "from public.activities",
    "pg_advisory_xact_lock",
  ]),
  /guard READ COMMITTED debe ser la primera lógica ejecutable/,
  "La regresión negativa debe rechazar autorización o lectura antes del guard",
);

assert.equal(
  [...sources.migration.matchAll(/sitaa_sem01_read_committed_required/g)].length,
  3,
  "Las tres rutas runtime deben usar exactamente el mensaje estable READ COMMITTED",
);
assert.match(sources.verify,
  /lock_and_reauthorize_sem01_admin_0011\(uuid\)[\s\S]*acquire_sem01_calendar_lock_0011\(\)[\s\S]*publish_activity\(uuid\)[\s\S]*sitaa_sem01_read_committed_required[\s\S]*25000[\s\S]*case_43_read_committed_guard_failed/i,
  "El caso 43 debe inspeccionar las tres definiciones desplegadas y su error estable");

const futureStartFixture = `
perform pg_advisory_xact_lock(1397310541, 1101);
select activity.* from public.activities activity for update;
validation_now := clock_timestamp();
if (start_value at time zone 'America/Mexico_City') <= validation_now then null; end if;`;
assertFutureStartWallClockContract(futureStartFixture, "fixture wall-clock canónica");
for (const staleClock of ["current_timestamp", "now()"]) {
  const staleFutureStartFixture = futureStartFixture.replace("clock_timestamp()", staleClock);
  assert.throws(
    () => assertFutureStartWallClockContract(
      staleFutureStartFixture,
      `fixture de reloj obsoleto ${staleClock}`,
    ),
    /falta capturar reloj de pared/,
    `La regresión negativa debe rechazar ${staleClock} después de una espera simulada`,
  );
}
assert.match(sources.migration, /before insert on public\.activities[\s\S]*for each statement[\s\S]*acquire_sem01_calendar_lock_0011/i,
  "Falta lock statement-level para INSERT de activities");
assert.match(sources.migration, /before update of start_date, status_code, academic_period_id on public\.activities[\s\S]*for each statement/i,
  "Falta lock statement-level para UPDATE relevante de activities");

for (const body of sources.migration.matchAll(/create(?:\s+or\s+replace)?\s+function\s+public\.[\s\S]*?\n\$function\$;/gi)) {
  if (/security\s+definer/i.test(body[0])) {
    assert.match(body[0], /set\s+search_path\s*=\s*pg_catalog,\s*public/i,
      "Toda función SECURITY DEFINER de 0011 debe fijar pg_catalog, public");
  }
}

assert.match(sources.migration, /exclude\s+using\s+gist[\s\S]*daterange\(starts_on, ends_on, '\[\]'\)\s+with\s+&&/i,
  "Falta exclusión GiST de rangos activos");
assert.match(sources.migration, /code\s*=\s*'pilot'[\s\S]*starts_on\s+is\s+null[\s\S]*ends_on\s+is\s+null/i,
  "pilot debe preservarse explícitamente");
for (const sourceName of ["preflight", "migration", "rollback"]) {
  assert.match(sources[sourceName], /8af9fc114f31320519e894770823cc1d/,
    `${sourceName} debe proteger la huella UUID|code histórica`);
}
for (const sourceName of ["preflight", "migration"]) {
  assert.match(sources[sourceName], /0382c9d760805ac4a3cfd8d6ca8a6951/,
    `${sourceName} debe congelar el ACL exacto de academic_periods`);
  assert.match(sources[sourceName], /d1707186c8e5f1577bde2338d7541aec/,
    `${sourceName} debe congelar el ACL de las firmas reemplazadas`);
  assert.doesNotMatch(
    sources[sourceName],
    /select\s+count\(\*\)\s+from\s+information_schema\.column_privileges\s+privilege\s+where\s+privilege\.table_schema\s*=\s*'public'[\s\S]*?privilege\.grantee\s+in\s*\('PUBLIC',\s*'anon',\s*'authenticated',\s*'service_role'\)/i,
    `${sourceName} no puede confundir la proyección column_privileges con attacl explícita`,
  );
  assert.match(sources[sourceName], /pg_catalog\.pg_attribute[\s\S]*attacl[\s\S]*pg_catalog\.aclexplode/i,
    `${sourceName} debe inventariar attacl con aclexplode`);
  for (const columnName of ["first_names", "paternal_surname", "maternal_surname"]) {
    assert.ok(
      sources[sourceName].includes(`('profiles','${columnName}','postgres','authenticated','UPDATE',false)`),
      `${sourceName} debe congelar UPDATE explícito de profiles.${columnName}`,
    );
  }
  assert.match(sources[sourceName], /select \* from actual except select \* from expected[\s\S]*select \* from expected except select \* from actual/i,
    `${sourceName} debe comparar attacl en ambos sentidos`);
  assert.match(sources[sourceName], /approved_projection[\s\S]*information_schema\.column_privileges/i,
    `${sourceName} debe distinguir la proyección table-derived`);
  assert.match(sources[sourceName], /has_table_privilege\(/i,
    `${sourceName} debe comprobar privilegios efectivos de tabla`);
  assert.match(sources[sourceName], /has_column_privilege\(/i,
    `${sourceName} debe comprobar privilegios efectivos de columna`);
  assert.match(sources[sourceName], /has_table_privilege\([\s\S]*'authenticated'[\s\S]*'public\.profiles'[\s\S]*'UPDATE'/i,
    `${sourceName} debe rechazar UPDATE de tabla para authenticated en profiles`);
}
assert.match(sources.migration, /create table public\.academic_period_audit_events/i,
  "Falta auditoría dedicada");
const auditTable = extractCreateTable(sources.migration, "academic_period_audit_events");
assert.match(auditTable, /occurred_at\s+timestamptz\s+not\s+null\s+default\s+clock_timestamp\(\)/i,
  "occurred_at debe tener semántica wall-clock");
assert.doesNotMatch(auditTable, /\b(?:current_timestamp|now\s*\(\s*\))/i,
  "La auditoría nueva no puede usar tiempo de inicio de transacción");
for (const functionName of [
  "create_admin_academic_period",
  "correct_admin_academic_period",
  "activate_admin_academic_period",
  "deactivate_admin_academic_period",
]) {
  const body = extractFunction(sources.migration, functionName);
  assert.match(body, /insert into public\.academic_period_audit_events\s*\([\s\S]*occurred_at[\s\S]*clock_timestamp\(\)/i,
    `${functionName} debe insertar occurred_at explícitamente con clock_timestamp()`);
  assert.doesNotMatch(body, /\b(?:current_timestamp|now\s*\(\s*\))/i,
    `${functionName} no puede fechar el evento con el inicio de transacción`);
}
assert.match(sources.verify, /lower_bound\s*:=\s*clock_timestamp\(\)[\s\S]*upper_bound\s*:=\s*clock_timestamp\(\)/i,
  "El verificador debe acotar el tiempo wall-clock de una mutación");
assert.match(sources.verify, /event\.occurred_at\s*>=\s*bounds\.lower_bound[\s\S]*event\.occurred_at\s*<=\s*bounds\.upper_bound/i,
  "El verificador debe probar occurred_at entre ambos límites");
assert.match(sources.verify, /event\.actor_profile_id\s*=\s*bounds\.actor_profile_id/i,
  "El evento acotado debe pertenecer al actor esperado");
assert.match(sources.migration, /academic_period_audit_events_guard_update_delete/i,
  "Falta guarda append-only");
assert.match(sources.migration, /revoke all privileges on table public\.academic_period_audit_events[\s\S]*public, anon, authenticated, service_role/i,
  "La auditoría no puede tener acceso cliente directo");
assert.match(sources.migration, /revoke all privileges on table public\.academic_periods from service_role/i,
  "Debe retirarse el DML directo de service_role");
assert.match(sources.migration, /observed_count\s*<>\s*20[\s\S]*<>\s*194[\s\S]*<>\s*105[\s\S]*<>\s*52[\s\S]*<>\s*75[\s\S]*unexpected_post_schema_inventory/i,
  "Faltan postcondiciones numéricas exactas de 0011");
assert.match(sources.testPlan, /20 tablas, 194 columnas, 105 restricciones, 52 índices, 20 triggers[\s\S]*75 funciones[\s\S]*25 políticas[\s\S]*20 tablas con RLS/i,
  "TEST_PLAN_0011 debe congelar el inventario post-0011");

const verifierCaseNumbers = exactVerifierCaseNumbers(sources.verify, "verificador 0011");
assert.match(sources.verify,
  /publication_definition[\s\S]*validator_definition[\s\S]*clock_timestamp\(\)[\s\S]*current_timestamp[\s\S]*transaction_timestamp[\s\S]*case_30_wall_clock_definition_failed/i,
  "El caso 30 debe inspeccionar las definiciones desplegadas para el contrato wall-clock");
assert.equal(verifierCaseNumbers.filter((caseNumber) => caseNumber === 37).length, 1,
  "El caso 37 debe registrarse una sola vez");
const authenticatedDenialEnd = sources.verify.indexOf("$case_37_direct_dml$;");
const serviceRoleDenialEnd = sources.verify.indexOf("$case_37_service_dml$;");
const case37PassOffset = sources.verify.indexOf("pg_temp.pass(37,");
assert.ok(authenticatedDenialEnd >= 0
  && serviceRoleDenialEnd > authenticatedDenialEnd
  && case37PassOffset > serviceRoleDenialEnd,
"El caso 37 sólo se registra tras las denegaciones authenticated y service_role");

const canonicalCaseFixture = Array.from(
  { length: 51 },
  (_, index) => `select pg_temp.pass(${index + 1}, 'fixture');`,
).join("\n");
assert.deepEqual(
  exactVerifierCaseNumbers(canonicalCaseFixture, "fixture canónica"),
  Array.from({ length: 51 }, (_, index) => index + 1),
);
const duplicateCaseFixture = canonicalCaseFixture.replace(
  "pg_temp.pass(51,",
  "pg_temp.pass(37,",
);
assert.throws(
  () => exactVerifierCaseNumbers(duplicateCaseFixture, "fixture duplicada"),
  /no se permiten casos duplicados/,
  "La regresión negativa debe rechazar un número de caso duplicado",
);

for (let caseNumber = 1; caseNumber <= 51; caseNumber += 1) {
  assert.match(sources.testPlan, new RegExp(`Caso\\s+${caseNumber}\\b`, "i"),
    `TEST_PLAN_0011 no documenta el caso ${caseNumber}`);
}
for (const caseNumber of [46, 47, 48, 49, 50, 51]) {
  assert.ok(sources.verify.includes(`pass(${caseNumber},`), `Falta caso crítico ${caseNumber}`);
}
assert.match(sources.verify, /to_jsonb\(activity\)[\s\S]*xmin::text[\s\S]*updated_at[\s\S]*status_code[\s\S]*created_by[\s\S]*responsible_profile_id[\s\S]*academic_period_id/i,
  "El caso 47 debe comparar la fila completa y campos obligatorios");
assert.match(sources.testPlan, /preflight independiente[\s\S]*obsolet[\s\S]*forma autoritativa[\s\S]*guarda post-lock/i,
  "TEST_PLAN_0011 debe distinguir preflight previo y barrera post-lock autoritativa");
assert.match(sources.testPlan, /borrador sin atribución que ya era resoluble[\s\S]*no puede perder[\s\S]*ni cambiar/i,
  "TEST_PLAN_0011 debe proteger borradores resolubles en la transición inicial");
assert.match(sources.testPlan, /clock_timestamp\(\)[\s\S]*posterior a la espera/i,
  "TEST_PLAN_0011 debe documentar la decisión futura con reloj de pared post-espera");
assert.match(sources.testPlan, /migración espera el lock estructural[\s\S]*hora de inicio pasa[\s\S]*validator debe rechazarla/i,
  "TEST_PLAN_0011 debe conservar los escenarios multisesión DB-03");

assert.match(sources.rollback, /academic_period_audit_events\)\s*<>\s*0/i,
  "Rollback debe bloquearse con historia de auditoría");
assert.match(sources.rollback, /rollback_dependent_activity_exists/i,
  "Rollback debe bloquearse ante actividades dependientes");
assert.doesNotMatch(sources.rollback, /\b(delete\s+from|truncate)\s+public\.(academic_periods|activities|academic_period_audit_events)\b/i,
  "Rollback no puede borrar historia");

const combined = Object.values(sources).join("\n");
assert.doesNotMatch(combined, /SUPABASE_DB_URL|service_role_key|BEGIN\s+PRIVATE\s+KEY|postgres(?:ql)?:\/\//i,
  "Los artefactos no pueden contener secretos o URI de conexión");
assert.doesNotMatch(combined, /\b(?:horizonte|reasonable)[-_ ]?(?:days|years|días|años)?\s*=\s*\d+/i,
  "No debe inventarse un horizonte razonable");

const packageJson = JSON.parse(read("package.json"));
assert.equal(packageJson.scripts["check:sql:0011"], "node scripts/check-sql-0011.mjs",
  "Falta check:sql:0011");
assert.ok(packageJson.scripts.build.includes("npm run check:sql:0011"),
  "build debe ejecutar check:sql:0011");

console.log("SQL 0011 válido: preflight, migración, verificador, rollback, ACL, locks y casos 1–51.");
