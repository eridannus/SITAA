param(
  [switch]$ValidateOnly,
  [switch]$ReadOnlyProbeOnly
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$scriptRoot = Split-Path -Parent $PSCommandPath
$repoRoot = [System.IO.Path]::GetFullPath((Join-Path $scriptRoot ".."))
$currentRoot = [System.IO.Path]::GetFullPath((Get-Location).Path)
$temporaryRoot = [System.IO.Path]::GetFullPath(
  (Join-Path $repoRoot (".sitaa-b3a-concurrency-runtime-" + [guid]::NewGuid().ToString("N")))
)
$nodeModulePath = Join-Path $temporaryRoot "hosted-auth-concurrency-boundaries.mjs"
$protectedLocalArtifactNames = @(
  "b3a_matrix_hosted_auth_core.local.txt",
  "b3a_matrix_hosted_auth_core_postcheck.local.txt",
  "b3a_matrix_failure_recovery_target_bootstrap.local.txt",
  "b3a_matrix_failure_recovery_target_bootstrap_postcheck.local.txt",
  "b3a_matrix_hosted_auth_failure_recovery.local.txt",
  "b3a_matrix_hosted_auth_failure_recovery_postcheck.local.txt",
  "b3a_matrix_hosted_auth_users.local.txt",
  "b3a_matrix_hosted_auth_concurrency_boundaries.local.txt",
  "b3a_matrix_hosted_auth_concurrency_boundaries_postcheck.local.txt",
  "b3a_matrix_hosted_auth_failure_recovery_confirmation_repair.local.txt",
  "b3a_matrix_failure_recovery_target_handler_repair.local.json",
  "b3a_matrix_failure_recovery_target_handler_repair.next.local.json",
  "b3a_matrix_failure_recovery_target_handler_repair.previous.local.json",
  "b3a_matrix_failure_recovery_target_handler_snapshot.local.sql",
  "b3a_matrix_failure_recovery_target_handler_snapshot.next.local.sql",
  "b3a_matrix_failure_recovery_target_handler_snapshot.previous.local.sql"
)

$nodeModule = @'
import crypto from "node:crypto";
import fs from "node:fs";
import path from "node:path";
import process from "node:process";
import readline from "node:readline/promises";
import { spawn, spawnSync } from "node:child_process";

const EXPECTED_PROJECT_REF = "upttfqjogltvymnaubkg";
const EXPECTED_PROJECT_URL = `https://${EXPECTED_PROJECT_REF}.supabase.co`;
const HARNESS_VERSION = "2026-08-05-hosted-auth-concurrency-boundaries-v7";
const TARGET_BOOTSTRAP_VERSION = "2026-08-04-b3a-failure-target-bootstrap-v7";
const EXPECTED_AUTH_HANDLER_MD5 = "156398fbb0da020e2b8b57db92b87fcd";
const EXPECTED_AUTH_HANDLER_ACL = "{postgres=X/postgres,service_role=X/postgres}";
const EXPECTED_AUTH_HANDLER_SIGNATURE = "public.handle_sitaa_auth_user_created()";
const EXPECTED_NODE_VERSION = "v24.18.0";
const EXPECTED_SUPABASE_JS_VERSION = "2.110.1";
const OPERATOR_ABORT_EXIT_CODE = 2;
const AUTH_REQUEST_TIMEOUT_MS = 20_000;
const POSTGRES_PROCESS_TIMEOUT_MS = 45_000;
const LEASE_WAIT_PROCESS_TIMEOUT_MS = 390_000;
const WORKER_MARKER_TIMEOUT_MS = 20_000;
const ADVISORY_OBSERVER_TIMEOUT_MS = 15_000;
const ADVISORY_OBSERVER_POLL_MS = 150;
const REQUIRED_ADVISORY_OBSERVATIONS = 7;
const POSTGRES_MAX_BUFFER_BYTES = 1024 * 1024;
const DEFAULT_POSTGRES_PORT = 5432;
const LEASE_WAIT_SECONDS = 301;
const EXPECTED_DELTA = Object.freeze({
  authUsers: 1,
  authIdentities: 0,
  profiles: 1,
  roleAssignments: 1,
  operations: 2,
  administrativeEvents: 4,
  authSuccessEvents: 2,
  authFailureEvents: 0,
});
const BASELINE_AGGREGATE_FIELDS = Object.freeze([
  "authUsers", "authIdentities", "profiles", "roleAssignments", "exactB1Authorities",
  "targetAuthUsers", "targetEmailIdentities", "targetProfiles", "targetAuthUsable", "targetRoleAssignments",
  "operations", "succeededCompletedOperations", "nonfinalOperations", "nonsucceededOperations",
  "administrativeEvents", "authFailureEvents", "authSuccessEvents", "validFunctions", "expectedFunctions",
  "ledgerTriggers", "authTriggerContract", "ledgerRlsEnabled", "ledgerPolicies", "adminAActive", "adminBActive",
]);
const EXPECTED_BASELINE_AGGREGATES = Object.freeze({
  authUsers: 3,
  authIdentities: 3,
  profiles: 3,
  roleAssignments: 2,
  exactB1Authorities: 2,
  targetAuthUsers: 1,
  targetEmailIdentities: 1,
  targetProfiles: 1,
  targetAuthUsable: 1,
  targetRoleAssignments: 0,
  operations: 4,
  succeededCompletedOperations: 4,
  nonfinalOperations: 0,
  nonsucceededOperations: 0,
  administrativeEvents: 8,
  authFailureEvents: 0,
  authSuccessEvents: 4,
  validFunctions: 6,
  expectedFunctions: 6,
  ledgerTriggers: 2,
  authTriggerContract: 2,
  ledgerRlsEnabled: 1,
  ledgerPolicies: 0,
  adminAActive: 1,
  adminBActive: 1,
});
const FINAL_POSTCHECK_AGGREGATE_FIELDS = Object.freeze([
  "authUsers", "authIdentities", "profiles", "roleAssignments", "exactB1Authorities",
  "targetActive", "targetAuthUsable", "targetRoleAssignments", "operations", "succeededCompletedOperations",
  "nonfinalOperations", "nonsucceededOperations", "administrativeEvents", "authFailureEvents",
  "authSuccessEvents", "adminAActive", "adminBActive", "adminAssignmentsPreserved", "syntheticAuthUsers",
  "syntheticProfiles", "syntheticAssignmentInactive", "activeLeases", "authTriggers", "targetIdentityPreserved",
  "targetActivatedAtPreserved",
]);
const EXPECTED_FINAL_POSTCHECK_AGGREGATES = Object.freeze({
  authUsers: 4,
  authIdentities: 3,
  profiles: 4,
  roleAssignments: 3,
  exactB1Authorities: 2,
  targetActive: 1,
  targetAuthUsable: 1,
  targetRoleAssignments: 0,
  operations: 6,
  succeededCompletedOperations: 6,
  nonfinalOperations: 0,
  nonsucceededOperations: 0,
  administrativeEvents: 12,
  authFailureEvents: 0,
  authSuccessEvents: 6,
  adminAActive: 1,
  adminBActive: 1,
  adminAssignmentsPreserved: 1,
  syntheticAuthUsers: 1,
  syntheticProfiles: 1,
  syntheticAssignmentInactive: 1,
  activeLeases: 0,
  authTriggers: 2,
  targetIdentityPreserved: 1,
  targetActivatedAtPreserved: 1,
});
const POSTGRES_SSL_MODES = new Set(["require", "verify-ca", "verify-full"]);
const UUID_PATTERN = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const HASH_PATTERN = /^[0-9a-f]{64}$/i;
const EXPECTED_ADMIN_ALIASES = new Set(["admin_a", "admin_b"]);
const TARGET_EMAIL_PATTERN = /^b3a-failure-target-\d{17}-[a-f0-9]{12}@example\.invalid$/;
const TARGET_EMAIL_SQL_PATTERN = "^b3a-failure-target-[0-9]{17}-[0-9a-f]{12}@example\\.invalid$";
const TARGET_FIRST_NAMES = "Objetivo Matriz C";
const SYNTHETIC_AUTHORITY_EMAIL_SQL_PATTERN = "^b3a-authority-d-[0-9a-f]{20}@example\\.invalid$";
const SAFE_EVIDENCE_TERMS = ["CASE_18_SERVICE_ROLE_BOUNDARY"];
const FORBIDDEN_EVIDENCE = /@|https?:|bearer|authorization|cookie|password|secret|access[_-]?token|refresh[_-]?token|eyj[a-z0-9_-]*\.|[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}/i;
const CLIENT_OPTIONS = Object.freeze({
  auth: {
    autoRefreshToken: false,
    persistSession: false,
    detectSessionInUrl: false,
  },
});
const POSTGRES_ENVIRONMENT_KEYS = new Set([
  "PGHOST", "PGHOSTADDR", "PGPORT", "PGDATABASE", "PGUSER", "PGPASSWORD",
  "PGPASSFILE", "PGSERVICE", "PGSERVICEFILE", "PGOPTIONS", "PGSSLMODE",
  "PGCONNECT_TIMEOUT", "PGAPPNAME", "PGCLIENTENCODING", "PG_COLOR",
]);
const PSQL_ARGUMENTS = Object.freeze(["-X", "-qAt", "-w", "-v", "ON_ERROR_STOP=1", "-f", "-"]);
const B3A_ALL_ACTIONS = Object.freeze([
  "account_deactivated", "account_reactivated", "account_auth_suspended",
  "account_auth_restored", "account_auth_suspension_failed", "account_auth_restoration_failed",
]);
const B3A_AUTH_ACTIONS = Object.freeze([
  "account_auth_suspended", "account_auth_restored",
  "account_auth_suspension_failed", "account_auth_restoration_failed",
]);
const REQUIRED_EVIDENCE = Object.freeze([
  Object.freeze({
    name: "b3a_matrix_hosted_auth_core.local.txt",
    bytes: 2008,
    sha256: "55315c6e4b9c34278d920f231bac48c7349a1f9da3b0d3d7e2516c90e2ea7cac",
    markers: Object.freeze(["HOSTED_AUTH_CORE_MATRIX|APPROVED"]),
  }),
  Object.freeze({
    name: "b3a_matrix_hosted_auth_core_postcheck.local.txt",
    bytes: 333,
    sha256: "29c38e45dd6b8b5ae3aec4dd57380aef46c1ed198e89be03b1a45477ed49a389",
    markers: Object.freeze(["B3A_CORE_POSTCHECK|APPROVED"]),
  }),
  Object.freeze({
    name: "b3a_matrix_failure_recovery_target_bootstrap.local.txt",
    bytes: null,
    sha256: "04fd4c7efca7079c61b5f7a12057d031783f83310383f55fdf28ffbc5663a2a1",
    markers: Object.freeze([
      `HARNESS_VERSION|${TARGET_BOOTSTRAP_VERSION}`,
      "FAILURE_TARGET_BOOTSTRAP|APPROVED",
      "AUTH_HANDLER_STATE|CANONICAL",
    ]),
  }),
  Object.freeze({
    name: "b3a_matrix_failure_recovery_target_bootstrap_postcheck.local.txt",
    bytes: null,
    sha256: "a1a814a599f14515fc9c4eb9fea18d176d149ede5d6d08a604a90c02127dac3f",
    markers: Object.freeze([
      `HARNESS_VERSION|${TARGET_BOOTSTRAP_VERSION}`,
      "FAILURE_TARGET_AUTH_CONTRACT|APPROVED",
      "FAILURE_TARGET_PROFILE_CONTRACT|APPROVED",
      "FAILURE_TARGET_ASSIGNMENTS|0",
      "AUTH_HANDLER_STATE|CANONICAL",
      "READ_ONLY_TRANSACTION|true",
      "ROLLBACK|true",
    ]),
  }),
  Object.freeze({
    name: "b3a_matrix_hosted_auth_failure_recovery.local.txt",
    bytes: 2167,
    sha256: "cf5653456e1ce1fca8b106bb4fb492f276f1f758eff10a3a643f88b13c743c8c",
    markers: Object.freeze([
      "HARNESS_VERSION|2026-08-04-hosted-auth-failure-recovery-v11",
      "FAILURE_RECOVERY_MATRIX|APPROVED",
    ]),
  }),
  Object.freeze({
    name: "b3a_matrix_hosted_auth_failure_recovery_postcheck.local.txt",
    bytes: 542,
    sha256: "3404ddcd6f9c028a28f9db21a38d2dfb70c60f0c94fb9f38277ff55ca6e0e1c7",
    markers: Object.freeze([
      "FAILURE_RECOVERY_POSTCHECK|APPROVED",
      "READ_ONLY_TRANSACTION|true",
      "ROLLBACK|true",
    ]),
  }),
]);
const REPAIR_ARTIFACT_NAMES = Object.freeze([
  "b3a_matrix_hosted_auth_failure_recovery_confirmation_repair.local.txt",
  "b3a_matrix_failure_recovery_target_handler_repair.local.json",
  "b3a_matrix_failure_recovery_target_handler_repair.next.local.json",
  "b3a_matrix_failure_recovery_target_handler_repair.previous.local.json",
  "b3a_matrix_failure_recovery_target_handler_snapshot.local.sql",
  "b3a_matrix_failure_recovery_target_handler_snapshot.next.local.sql",
  "b3a_matrix_failure_recovery_target_handler_snapshot.previous.local.sql",
]);
const EXPECTED_PACKAGE_HASHES = new Map([
  ["supabase/migrations/0010_coordinated_auth_session_suspension.sql", "d7354dd40c1696a02574cb2d72e81d016ce5419e4164641bd731c841251f493a"],
  ["supabase/reconciliation/0010_coordinated_auth_session_suspension_preflight.sql", "453bdd70542031c5cb8be1d9d0d9926b1340ac8963b6695280e477afaa48c010"],
  ["supabase/reconciliation/0010_coordinated_auth_session_suspension_verify.sql", "727c6e41e1ea268220dff141295621405d2dcc13dfab2d0ad6ff36e36cdb3505"],
  ["supabase/reconciliation/0010_coordinated_auth_session_suspension_rollback.sql", "188504d674db7c565e877dc8195b3c90a38a663e79d2a8a78dae17a18beab9bf"],
  ["supabase/functions/admin-account-auth-lifecycle/index.ts", "5d7118a339f7854519c064c205453bb505f1a7b19185d62bc9177e696a774ad5"],
  ["supabase/functions/admin-account-auth-lifecycle/auth-admin-adapter.ts", "83acccb558c03564b36512d772f84adb8e7b58157efbd592e5e253b7befd4bef"],
  ["supabase/config.toml", "7e1e56068cc365012849513870bd268aee73c0488451372bbd50a85f54b772e4"],
  ["scripts/check-auth-lifecycle-b3a.mjs", "b52ab78a66866033aec2ca6f1f5b010d3a298efe4fa2d067299414a9ecba249d"],
  ["scripts/check-sql-0010.mjs", "2317779a416bebb1fed851ec25165a51cb773ed94ee5dfa733ae8daada1110f9"],
  ["docs/TEST_PLAN_0010.md", "ad5c929777a3821c3c430b8e2a625e9081f399b9c62159d1c2e69c6fa68795a0"],
  ["app/admin/accounts/[id]/lifecycle/page.tsx", "bebc3d03cdb5c57270ac6caa104a78508a3eb2de98e62b467ecac0a290915115"],
  ["app/admin/accounts/[id]/lifecycle/actions.ts", "8829011e55f11b3031d9cb54a6b67213c5bc86741c3ca6548fb3d817274fbd49"],
  ["app/admin/accounts/[id]/lifecycle/account-lifecycle-form.tsx", "0f539eeda7a8c94b7e4b8f91a7d1f96d35efcc6895549cf8a43f6c522d3a6793"],
  ["lib/admin/account-lifecycle.ts", "b164de244bb1ba0f18396e5e7822fb60a42b78f77389d8c0ffe916cc951ed03c"],
  ["lib/admin/account-lifecycle-permissions.ts", "6c5f8a31772f4d5b2e8fc0b57008160754873d7b7a56e857f58c06141e91ad38"],
  ["types/admin.ts", "662094633280f220bb0a9e4fea7bf4480af4752562061fe7c6dd61482d14d617"],
]);
const runtimeState = {
  phase: "initial",
  irreversible: false,
  databaseConnection: null,
  evidencePath: null,
  postcheckPath: null,
  runDirectory: null,
  syntheticAuthorityId: null,
  syntheticAuthorityAssignmentId: null,
  syntheticAuthorityEnabled: false,
  liveWorkers: new Set(),
  advisoryObservations: 0,
  approvedPhases: [],
};
let createSupabaseClient = null;

class SafeFailure extends Error {
  constructor(code) {
    super(code);
    this.name = "SafeFailure";
    this.code = code;
  }
}

function fail(code) {
  throw new SafeFailure(code);
}

function requireCondition(condition, code) {
  if (!condition) fail(code);
}

function normalizeEol(value) {
  return String(value ?? "").replace(/\r\n?/g, "\n");
}

function exactObject(value, keys) {
  return value !== null && typeof value === "object" && !Array.isArray(value)
    && Object.keys(value).sort().join("|") === [...keys].sort().join("|");
}

function oneRow(value) {
  return Array.isArray(value) && value.length === 1 && value[0] && typeof value[0] === "object"
    ? value[0]
    : null;
}

function utcNow() {
  return new Date().toISOString();
}

function sha256Buffer(value) {
  return crypto.createHash("sha256").update(value).digest("hex");
}

function readRequiredBuffer(filePath, failureCode) {
  try {
    return fs.readFileSync(filePath);
  } catch {
    fail(failureCode);
  }
}

function readRequiredText(filePath, failureCode) {
  return readRequiredBuffer(filePath, failureCode).toString("utf8");
}

function containsForbiddenEvidence(value) {
  let candidate = String(value ?? "");
  for (const term of SAFE_EVIDENCE_TERMS) candidate = candidate.replaceAll(term, "SAFE_TERM");
  return FORBIDDEN_EVIDENCE.test(candidate);
}

function parseNumericAggregate(values, fields, failureCode) {
  requireCondition(
    Array.isArray(values)
      && values.length === fields.length
      && values.every((value) => /^(0|[1-9][0-9]*)$/.test(String(value))),
    failureCode,
  );
  return Object.freeze(Object.fromEntries(fields.map((field, index) => [field, String(values[index])])));
}

function numericAggregateChain(aggregate, fields, failureCode) {
  requireCondition(exactObject(aggregate, fields), failureCode);
  const values = fields.map((field) => String(aggregate[field]));
  requireCondition(values.every((value) => /^(0|[1-9][0-9]*)$/.test(value)), failureCode);
  return values.join("|");
}

function formatBaselineCountsDiagnostic(actual, expected = EXPECTED_BASELINE_AGGREGATES) {
  const actualChain = numericAggregateChain(actual, BASELINE_AGGREGATE_FIELDS, "baseline_counts_diagnostic_rejected");
  const expectedChain = numericAggregateChain(expected, BASELINE_AGGREGATE_FIELDS, "baseline_counts_diagnostic_rejected");
  const diagnostic = `CONCURRENCY_BOUNDARIES_BASELINE_COUNTS|actual=${actualChain}|expected=${expectedChain}`;
  requireCondition(
    actualChain.split("|").length === 25
      && expectedChain.split("|").length === 25
      && !containsForbiddenEvidence(diagnostic),
    "baseline_counts_diagnostic_rejected",
  );
  return diagnostic;
}

function requireBaselineAggregates(actual) {
  const actualChain = numericAggregateChain(actual, BASELINE_AGGREGATE_FIELDS, "baseline_counts_rejected");
  const expectedChain = numericAggregateChain(
    EXPECTED_BASELINE_AGGREGATES,
    BASELINE_AGGREGATE_FIELDS,
    "baseline_counts_rejected",
  );
  if (actualChain !== expectedChain) {
    console.error(formatBaselineCountsDiagnostic(actual));
    fail("baseline_counts_rejected");
  }
  return true;
}

function requireFinalPostcheckAggregates(actual) {
  requireCondition(
    numericAggregateChain(actual, FINAL_POSTCHECK_AGGREGATE_FIELDS, "final_postcheck_rejected")
      === numericAggregateChain(
        EXPECTED_FINAL_POSTCHECK_AGGREGATES,
        FINAL_POSTCHECK_AGGREGATE_FIELDS,
        "final_postcheck_rejected",
      ),
    "final_postcheck_rejected",
  );
  return true;
}

function assertSafeEvidenceLine(line) {
  requireCondition(
    typeof line === "string"
      && line.length > 0
      && line.length <= 240
      && /^[A-Za-z0-9_./:=+|-]+$/.test(line)
      && !containsForbiddenEvidence(line),
    "unsafe_evidence_line",
  );
  return line;
}

function validateRequiredEvidence(reconciliationRoot) {
  const hashes = new Map();
  for (const contract of REQUIRED_EVIDENCE) {
    const filePath = path.join(reconciliationRoot, contract.name);
    const buffer = readRequiredBuffer(filePath, "required_evidence_missing");
    if (contract.bytes !== null) requireCondition(buffer.length === contract.bytes, "required_evidence_size_rejected");
    const observedHash = sha256Buffer(buffer);
    requireCondition(observedHash === contract.sha256, "required_evidence_hash_rejected");
    const text = normalizeEol(buffer.toString("utf8"));
    requireCondition(!text.includes("REJECTED"), "required_evidence_rejected_marker");
    for (const marker of contract.markers) requireCondition(text.includes(marker), "required_evidence_marker_missing");
    hashes.set(contract.name, observedHash);
  }
  for (const name of REPAIR_ARTIFACT_NAMES) {
    requireCondition(!fs.existsSync(path.join(reconciliationRoot, name)), "repair_artifact_present");
  }
  return hashes;
}

function validatePackageHashes(repoRoot) {
  for (const [relativePath, expectedHash] of EXPECTED_PACKAGE_HASHES) {
    const observed = sha256Buffer(readRequiredBuffer(path.join(repoRoot, relativePath), "package_artifact_missing"));
    requireCondition(observed === expectedHash, "package_artifact_hash_rejected");
  }
}

function readSupabaseJsVersion(repoRoot) {
  const packageJson = JSON.parse(readRequiredText(path.join(repoRoot, "node_modules", "@supabase", "supabase-js", "package.json"), "supabase_js_missing"));
  requireCondition(packageJson.version === EXPECTED_SUPABASE_JS_VERSION, "supabase_js_version_rejected");
  return packageJson.version;
}

async function loadSupabaseJs(repoRoot) {
  const modulePath = path.join(repoRoot, "node_modules", "@supabase", "supabase-js", "dist", "index.mjs");
  const imported = await import(new URL(`file:///${modulePath.replace(/\\/g, "/")}`).href);
  requireCondition(typeof imported.createClient === "function", "supabase_js_contract_rejected");
  createSupabaseClient = imported.createClient;
  return readSupabaseJsVersion(repoRoot);
}

function isThreeSegmentJwt(value) {
  return typeof value === "string" && /^[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+$/.test(value);
}

function validatePublicApiKey(value) {
  requireCondition(typeof value === "string" && (value.startsWith("sb_publishable_") || isThreeSegmentJwt(value)), "public_api_key_rejected");
  return value;
}

function validatePrivilegedApiKey(value) {
  requireCondition(typeof value === "string" && (value.startsWith("sb_secret_") || isThreeSegmentJwt(value)), "privileged_api_key_rejected");
  return value;
}

function isOpaqueApiKey(value) {
  return typeof value === "string" && (value.startsWith("sb_publishable_") || value.startsWith("sb_secret_"));
}

function boundedRequestInit(init = {}, timeoutMs = AUTH_REQUEST_TIMEOUT_MS) {
  const timeoutSignal = AbortSignal.timeout(timeoutMs);
  const signal = init.signal ? AbortSignal.any([init.signal, timeoutSignal]) : timeoutSignal;
  return { ...init, signal };
}

function apiKeyAwareRequestInit(apiKey, init = {}, timeoutMs = AUTH_REQUEST_TIMEOUT_MS) {
  const headers = new Headers(init.headers ?? {});
  const authorization = headers.get("authorization");
  if (isOpaqueApiKey(apiKey) && authorization === `Bearer ${apiKey}`) headers.delete("authorization");
  return boundedRequestInit({ ...init, headers }, timeoutMs);
}

function createApiKeyAwareBoundedFetch(apiKey, fetchImplementation = fetch, timeoutMs = AUTH_REQUEST_TIMEOUT_MS) {
  return (input, init = {}) => fetchImplementation(input, apiKeyAwareRequestInit(apiKey, init, timeoutMs));
}

function createIsolatedClient(projectUrl, key) {
  requireCondition(typeof createSupabaseClient === "function", "supabase_client_factory_missing");
  return createSupabaseClient(projectUrl, key, {
    ...CLIENT_OPTIONS,
    global: { fetch: createApiKeyAwareBoundedFetch(key) },
  });
}

function authRequestFailureCode(error, fallbackCode) {
  const name = String(error?.name ?? "");
  if (name === "AbortError" || name === "TimeoutError") return "auth_request_timeout";
  return fallbackCode;
}

async function authRequest(callback, fallbackCode) {
  try {
    return await callback();
  } catch (error) {
    fail(authRequestFailureCode(error, fallbackCode));
  }
}

function sqlLiteralUuid(value) {
  requireCondition(UUID_PATTERN.test(value), "invalid_fixture_uuid");
  return `'${value}'::uuid`;
}

function sqlLiteralText(value) {
  requireCondition(typeof value === "string" && value.length > 0, "invalid_fixture_text");
  return `'${value.replace(/'/g, "''")}'::text`;
}

function parseFixtureUsers(contents) {
  const rows = normalizeEol(contents).split("\n").map((line) => line.trim()).filter((line) => line.startsWith("AUTH_CREATED|"));
  requireCondition(rows.length === 2, "fixture_user_count_invalid");
  const users = new Map();
  for (const row of rows) {
    const fields = row.split("|");
    requireCondition(fields.length === 4, "fixture_user_shape_invalid");
    const [, alias, email, id] = fields;
    requireCondition(EXPECTED_ADMIN_ALIASES.has(alias) && !users.has(alias), "fixture_alias_invalid");
    requireCondition(/^[a-z0-9][a-z0-9._+-]*@example\.invalid$/.test(email), "fixture_email_invalid");
    requireCondition(UUID_PATTERN.test(id), "fixture_uuid_invalid");
    users.set(alias, Object.freeze({ email, id }));
  }
  requireCondition(users.get("admin_a").id !== users.get("admin_b").id, "fixture_users_not_distinct");
  return users;
}

function parsePostgresConnectionUri(dbUrl) {
  requireCondition(typeof dbUrl === "string" && dbUrl.length > 0, "database_url_rejected");
  let parsed;
  try { parsed = new URL(dbUrl); } catch { fail("database_url_rejected"); }
  requireCondition(parsed.protocol === "postgresql:" || parsed.protocol === "postgres:", "database_url_rejected");
  requireCondition(parsed.hostname.length > 0 && parsed.username.length > 0 && parsed.password.length > 0, "database_url_rejected");
  requireCondition(parsed.hash === "", "database_url_rejected");
  const decode = (value) => { try { return decodeURIComponent(value); } catch { fail("database_url_rejected"); } };
  const username = decode(parsed.username);
  const password = decode(parsed.password);
  const encodedDatabase = parsed.pathname.startsWith("/") ? parsed.pathname.slice(1) : parsed.pathname;
  requireCondition(encodedDatabase.length > 0 && !encodedDatabase.includes("/"), "database_url_rejected");
  const database = decode(encodedDatabase);
  requireCondition(database === "postgres", "database_url_rejected");
  requireCondition(!/[\u0000-\u001f\u007f]/.test(`${username}${password}${database}`), "database_url_rejected");
  const portText = parsed.port || String(DEFAULT_POSTGRES_PORT);
  requireCondition(/^\d{1,5}$/.test(portText), "database_url_rejected");
  const port = Number(portText);
  requireCondition(Number.isInteger(port) && port >= 1 && port <= 65535, "database_url_rejected");
  const queryKeys = [...parsed.searchParams.keys()];
  requireCondition(queryKeys.every((key) => key === "sslmode"), "database_url_rejected");
  const sslModes = parsed.searchParams.getAll("sslmode");
  requireCondition(sslModes.length <= 1, "database_url_rejected");
  const sslmode = sslModes[0] || "require";
  requireCondition(POSTGRES_SSL_MODES.has(sslmode), "database_url_rejected");
  const identityTokens = `${username}.${parsed.hostname}`.toLowerCase().split(/[^a-z0-9]+/).filter(Boolean);
  requireCondition(identityTokens.includes(EXPECTED_PROJECT_REF), "database_url_rejected");
  return Object.freeze({ hostname: parsed.hostname, port: String(port), username, password, database, sslmode });
}

function psqlExecutable() {
  const executable = process.env.SITAA_B3A_PSQL_PATH ?? "";
  requireCondition(path.isAbsolute(executable) && /^psql(?:\.exe)?$/i.test(path.basename(executable)), "psql_executable_rejected");
  return executable;
}

function postgresChildEnvironment(
  connection,
  statementTimeoutMs = 30_000,
  sourceEnvironment = process.env,
  applicationName = "sitaa_b3a_concurrency_boundaries",
) {
  requireCondition(/^[a-z][a-z0-9_]{0,62}$/.test(applicationName), "postgres_application_name_rejected");
  const environment = {};
  for (const [key, value] of Object.entries(sourceEnvironment)) {
    const upperKey = key.toUpperCase();
    if (upperKey.startsWith("SITAA_B3A_") || POSTGRES_ENVIRONMENT_KEYS.has(upperKey)) continue;
    environment[key] = value;
  }
  Object.assign(environment, {
    PGHOST: connection.hostname,
    PGPORT: connection.port,
    PGUSER: connection.username,
    PGPASSWORD: connection.password,
    PGDATABASE: connection.database,
    PGSSLMODE: connection.sslmode,
    PGCONNECT_TIMEOUT: "10",
    PGOPTIONS: `-c statement_timeout=${statementTimeoutMs} -c lock_timeout=5000`,
    PGAPPNAME: applicationName,
    PGCLIENTENCODING: "UTF8",
    PG_COLOR: "never",
  });
  return environment;
}

function classifyPsqlFailure(result) {
  if (result?.timedOut || result?.error?.code === "ETIMEDOUT") return "database_process_timeout";
  const stderr = String(result?.stderr ?? "");
  if (/password authentication failed|no password supplied|password (?:is )?required|fe_sendauth|contraseña/i.test(stderr)) return "database_password_unavailable";
  if (result?.status === 0 && !result?.error) return null;
  if (result?.status === 2) return "database_connection_failed";
  if (result?.status === 3) return "database_script_failed";
  return "database_check_failed";
}

function spawnPsqlSync(connection, sql, { timeoutMs = POSTGRES_PROCESS_TIMEOUT_MS, statementTimeoutMs = 30_000 } = {}) {
  return spawnSync(psqlExecutable(), PSQL_ARGUMENTS, {
    cwd: process.env.SITAA_B3A_REPO_ROOT,
    encoding: "utf8",
    env: postgresChildEnvironment(connection, statementTimeoutMs),
    input: `${normalizeEol(sql).trim()}\n`,
    windowsHide: true,
    timeout: timeoutMs,
    maxBuffer: POSTGRES_MAX_BUFFER_BYTES,
  });
}

function parsePsqlLines(result) {
  const failureCode = classifyPsqlFailure(result);
  if (failureCode) fail(failureCode);
  return normalizeEol(String(result.stdout ?? "")).split("\n").map((line) => line.trim()).filter(Boolean);
}

function parsePsqlMarker(result, expectedPrefix) {
  const matches = parsePsqlLines(result).filter((line) => line.startsWith(`${expectedPrefix}|`));
  requireCondition(matches.length === 1, "database_result_invalid");
  return matches[0].split("|");
}

function executeReadOnlySql(connection, sql, expectedPrefix) {
  const normalized = normalizeEol(sql).trim();
  requireCondition(/^begin;\nset transaction read only;/i.test(normalized), "sql_not_read_only");
  requireCondition(/\nrollback;$/i.test(normalized), "sql_missing_rollback");
  requireCondition(!/\b(insert|update|delete|alter|drop|truncate|grant|revoke|create|call|do)\b/i.test(normalized.replace(/'[^']*'/g, "''")), "sql_contains_write");
  return parsePsqlMarker(spawnPsqlSync(connection, normalized), expectedPrefix);
}

function executeTransactionalSql(connection, sql, expectedPrefix, options = {}) {
  const normalized = normalizeEol(sql).trim();
  requireCondition(/^begin;/i.test(normalized), "transactional_sql_missing_begin");
  requireCondition(/\n(?:commit|rollback);$/i.test(normalized), "transactional_sql_missing_end");
  return parsePsqlMarker(spawnPsqlSync(connection, normalized, options), expectedPrefix);
}

async function readMasked(promptText) {
  requireCondition(Boolean(process.stdin.isTTY && process.stdout.isTTY), "interactive_terminal_required");
  process.stdout.write(promptText);
  process.stdin.setRawMode(true);
  process.stdin.resume();
  process.stdin.setEncoding("utf8");
  let value = "";
  try {
    return await new Promise((resolve, reject) => {
      const onData = (character) => {
        if (character === "\u0003") {
          process.stdin.off("data", onData);
          reject(new SafeFailure("operator_cancelled"));
          return;
        }
        if (character === "\r" || character === "\n") {
          process.stdin.off("data", onData);
          process.stdout.write("\n");
          resolve(value);
          return;
        }
        if (character === "\u0008" || character === "\u007f") value = value.slice(0, -1);
        else value += character;
      };
      process.stdin.on("data", onData);
    });
  } finally {
    process.stdin.setRawMode(false);
    process.stdin.pause();
  }
}

async function readConfirmation(expected, promptText) {
  requireCondition(Boolean(process.stdin.isTTY && process.stdout.isTTY), "interactive_terminal_required");
  if (promptText) process.stdout.write(`${promptText}\n`);
  const prompt = readline.createInterface({ input: process.stdin, output: process.stdout });
  try {
    const value = await prompt.question("> ");
    return value === expected;
  } finally {
    prompt.close();
  }
}

function clearCollectedCredentials(credentials) {
  if (!credentials || typeof credentials !== "object") return;
  for (const key of Object.keys(credentials)) credentials[key] = "";
}

function finishControlledExit(credentials, exitCode) {
  clearCollectedCredentials(credentials);
  runtimeState.databaseConnection = null;
  createSupabaseClient = null;
  process.exitCode = exitCode;
}

const SNAPSHOT_FIELDS = [
  "operation_id", "target_profile_id", "operation_code", "status", "completed_stage",
  "attempt_count", "retryable", "last_error_code", "updated_at",
];
const CLAIM_FIELDS = [...SNAPSHOT_FIELDS, "claimed"];

function parseOperationSnapshot(data, expected = {}) {
  const row = oneRow(data);
  if (!row || !exactObject(row, SNAPSHOT_FIELDS)) return null;
  if (!UUID_PATTERN.test(row.operation_id) || !UUID_PATTERN.test(row.target_profile_id)) return null;
  if (!new Set(["deactivate", "reactivate"]).has(row.operation_code)) return null;
  if (!new Set(["open", "processing", "retryable_failure", "succeeded", "terminal_failure"]).has(row.status)) return null;
  if (!new Set(["prepared", "profile_suspended", "auth_synchronized", "completed"]).has(row.completed_stage)) return null;
  if (!Number.isSafeInteger(row.attempt_count) || row.attempt_count < 0) return null;
  if (typeof row.retryable !== "boolean" || row.retryable !== (row.status === "retryable_failure")) return null;
  if (row.last_error_code !== null && typeof row.last_error_code !== "string") return null;
  if (typeof row.updated_at !== "string" || !Number.isFinite(Date.parse(row.updated_at))) return null;
  if (expected.operationId && row.operation_id !== expected.operationId) return null;
  if (expected.targetId && row.target_profile_id !== expected.targetId) return null;
  if (expected.transition && row.operation_code !== expected.transition) return null;
  return Object.freeze({
    operationId: row.operation_id,
    targetId: row.target_profile_id,
    transition: row.operation_code,
    status: row.status,
    completedStage: row.completed_stage,
    attemptCount: row.attempt_count,
    retryable: row.retryable,
    lastErrorCode: row.last_error_code,
    updatedAt: row.updated_at,
  });
}

function parseClaim(data, expectedOperationId) {
  const row = oneRow(data);
  if (!row || !exactObject(row, CLAIM_FIELDS) || typeof row.claimed !== "boolean") return null;
  const snapshotRow = { ...row };
  delete snapshotRow.claimed;
  const snapshot = parseOperationSnapshot([snapshotRow], { operationId: expectedOperationId });
  return snapshot ? Object.freeze({ ...snapshot, claimed: row.claimed }) : null;
}

function databaseErrorMatches(error, code, message) {
  return Boolean(error)
    && String(error.code ?? "") === code
    && String(error.message ?? "").toLowerCase().includes(message.toLowerCase());
}

function buildStartPayload(targetProfileId, transition, reason, requestId) {
  requireCondition(UUID_PATTERN.test(targetProfileId) && UUID_PATTERN.test(requestId), "edge_payload_uuid_invalid");
  requireCondition(transition === "deactivate" || transition === "reactivate", "edge_payload_transition_invalid");
  const normalizedReason = typeof reason === "string" ? reason.replace(/\s+/g, " ").trim() : "";
  requireCondition(normalizedReason.length >= 10 && normalizedReason.length <= 1000, "edge_payload_reason_invalid");
  return { mode: "start", targetProfileId, transition, reason: normalizedReason, requestId };
}

function buildRetryPayload(operationId) {
  requireCondition(UUID_PATTERN.test(operationId), "edge_payload_uuid_invalid");
  return { mode: "retry", operationId };
}

async function prepareOperation(client, targetId, transition, reason, requestId) {
  const normalizedReason = reason.replace(/\s+/g, " ").trim();
  const result = await authRequest(() => client.rpc("prepare_admin_account_auth_lifecycle_b3a", {
    requested_profile_id: targetId,
    requested_transition: transition,
    transition_reason: normalizedReason,
    request_id: requestId,
  }), "prepare_operation_request_failed");
  return result.error
    ? { error: result.error, operation: null }
    : { error: null, operation: parseOperationSnapshot(result.data, { targetId, transition }) };
}

async function claimOperation(serviceClient, operationId, actorId, expectedClaimed = true) {
  const result = await authRequest(() => serviceClient.rpc("claim_admin_auth_operation_b3a", {
    requested_operation_id: operationId,
    caller_profile_id: actorId,
  }), "claim_operation_request_failed");
  requireCondition(!result.error, "claim_operation_failed");
  const claim = parseClaim(result.data, operationId);
  requireCondition(claim && claim.claimed === expectedClaimed, "claim_operation_rejected");
  return claim;
}

async function recordOperationResult(serviceClient, operation, actorId, requestedResult, stableErrorCode) {
  const result = await authRequest(() => serviceClient.rpc("record_admin_auth_operation_result_b3a", {
    requested_operation_id: operation.operationId,
    caller_profile_id: actorId,
    claimed_attempt_count: operation.attemptCount,
    requested_result: requestedResult,
    stable_error_code: stableErrorCode,
  }), "record_operation_result_request_failed");
  requireCondition(!result.error, "record_operation_result_failed");
  const snapshot = parseOperationSnapshot(result.data, { operationId: operation.operationId });
  requireCondition(snapshot !== null, "record_operation_result_malformed");
  return snapshot;
}

async function edgeResponse(client, payload) {
  const result = await authRequest(
    () => client.functions.invoke("admin-account-auth-lifecycle", { body: payload }),
    "edge_request_failed",
  );
  let data = result.data;
  let httpStatus = result.error ? null : 200;
  if (result.error) {
    try {
      const context = result.error.context;
      if (context && typeof context.clone === "function") {
        httpStatus = Number(context.status ?? 0) || null;
        if (!data || typeof data !== "object") data = await context.clone().json();
      }
    } catch {
      if (!data || typeof data !== "object") data = null;
    }
  }
  requireCondition(
    data && exactObject(data, ["code", "state", "operationId"])
      && typeof data.code === "string" && typeof data.state === "string"
      && (data.operationId === null || UUID_PATTERN.test(data.operationId)),
    "edge_response_malformed",
  );
  return Object.freeze({ data, hadTransportError: Boolean(result.error), httpStatus });
}

async function signInExact(client, email, password, expectedId, failureCode) {
  const result = await authRequest(() => client.auth.signInWithPassword({ email, password }), failureCode);
  requireCondition(!result.error && result.data?.session && result.data?.user, failureCode);
  requireCondition(result.data.user.id === expectedId, "authenticated_user_mismatch");
  return result.data.session;
}

async function refreshExact(client, session, expectedId, failureCode) {
  requireCondition(typeof session?.refresh_token === "string" && session.refresh_token.length > 0, failureCode);
  const result = await authRequest(() => client.auth.refreshSession({ refresh_token: session.refresh_token }), failureCode);
  requireCondition(!result.error && result.data?.session && result.data?.user, failureCode);
  requireCondition(result.data.user.id === expectedId, "refreshed_user_mismatch");
  return result.data.session;
}

async function listAllAuthUsers(serviceClient) {
  const users = [];
  const perPage = 200;
  for (let page = 1; page <= 100; page += 1) {
    const result = await authRequest(() => serviceClient.auth.admin.listUsers({ page, perPage }), "auth_user_inventory_failed");
    requireCondition(!result.error && Array.isArray(result.data?.users), "auth_user_inventory_failed");
    users.push(...result.data.users);
    if (result.data.users.length < perPage) return users;
  }
  fail("auth_user_inventory_unbounded");
}

function validateListedAuthUserIds(users) {
  requireCondition(Array.isArray(users) && users.length === 3, "auth_user_inventory_count_rejected");
  const ids = users.map((user) => {
    requireCondition(user && typeof user === "object" && !Array.isArray(user) && UUID_PATTERN.test(user.id), "auth_user_inventory_failed");
    return user.id;
  });
  requireCondition(new Set(ids).size === ids.length, "auth_user_inventory_duplicate_rejected");
  return Object.freeze(ids);
}

async function getDetailedAuthUser(serviceClient, expectedUserId, failureCode = "auth_user_detail_fetch_failed") {
  requireCondition(UUID_PATTERN.test(expectedUserId), "auth_user_detail_response_rejected");
  const result = await authRequest(
    () => serviceClient.auth.admin.getUserById(expectedUserId),
    failureCode,
  );
  requireCondition(!result?.error, failureCode);
  const user = result?.data?.user;
  requireCondition(
    user
      && typeof user === "object"
      && !Array.isArray(user)
      && UUID_PATTERN.test(user.id)
      && user.id === expectedUserId
      && typeof user.email === "string"
      && user.email.trim().length > 0,
    "auth_user_detail_response_rejected",
  );
  return user;
}

async function loadDetailedAuthUsers(serviceClient, expectedUserIds) {
  requireCondition(
    Array.isArray(expectedUserIds) && expectedUserIds.length === 3 && new Set(expectedUserIds).size === 3,
    "auth_user_detail_set_rejected",
  );
  const users = [];
  for (const expectedUserId of expectedUserIds) {
    users.push(await getDetailedAuthUser(serviceClient, expectedUserId, "auth_user_detail_fetch_failed"));
  }
  return Object.freeze(users);
}

function validateDetailedEmailIdentity(user) {
  requireCondition(
    user
      && typeof user === "object"
      && !Array.isArray(user)
      && UUID_PATTERN.test(user.id)
      && typeof user.email === "string"
      && user.email.trim().length > 0
      && user.is_anonymous === false
      && Array.isArray(user.identities)
      && user.identities.length === 1,
    "auth_user_detail_identity_contract_rejected",
  );
  const identity = user.identities[0];
  requireCondition(
    identity
      && typeof identity === "object"
      && !Array.isArray(identity)
      && identity.user_id === user.id
      && identity.identity_data
      && typeof identity.identity_data === "object"
      && !Array.isArray(identity.identity_data)
      && identity.identity_data.sub === user.id,
    "auth_user_detail_identity_contract_rejected",
  );
  requireCondition(
    identity.provider === "email"
      && typeof identity.identity_data.email === "string"
      && identity.identity_data.email.toLowerCase() === user.email.toLowerCase(),
    "auth_user_detail_email_identity_rejected",
  );
  return true;
}

function validateDetailedAuthInventory(listedUserIds, detailedUsers) {
  requireCondition(
    Array.isArray(listedUserIds)
      && listedUserIds.length === 3
      && new Set(listedUserIds).size === 3
      && Array.isArray(detailedUsers)
      && detailedUsers.length === 3,
    "auth_user_detail_set_rejected",
  );
  const detailedIds = detailedUsers.map((user) => {
    requireCondition(user && typeof user === "object" && !Array.isArray(user) && UUID_PATTERN.test(user.id), "auth_user_detail_response_rejected");
    return user.id;
  });
  requireCondition(
    new Set(detailedIds).size === 3
      && [...listedUserIds].sort().join("|") === [...detailedIds].sort().join("|"),
    "auth_user_detail_set_rejected",
  );
  for (const user of detailedUsers) validateDetailedEmailIdentity(user);
  const counts = Object.freeze({
    users: detailedUsers.length,
    identityArrays: detailedUsers.filter((user) => Array.isArray(user.identities)).length,
    identities: detailedUsers.reduce((total, user) => total + user.identities.length, 0),
    emailIdentities: detailedUsers.reduce(
      (total, user) => total + user.identities.filter((identity) => identity.provider === "email").length,
      0,
    ),
  });
  requireCondition(
    counts.users === 3
      && counts.identityArrays === 3
      && counts.identities === 3
      && counts.emailIdentities === 3,
    "auth_user_detail_identity_contract_rejected",
  );
  return counts;
}

function assertSafeAuthDetailDiagnostic(line) {
  requireCondition(
    typeof line === "string"
      && /^AUTH_ADMIN_DETAIL_COUNTS\|users=(0|[1-9][0-9]*)\|identity_arrays=(0|[1-9][0-9]*)\|identities=(0|[1-9][0-9]*)\|email_identities=(0|[1-9][0-9]*)$/.test(line)
      && !containsForbiddenEvidence(line),
    "auth_user_detail_diagnostic_rejected",
  );
  return line;
}

function formatAuthDetailDiagnostic(counts) {
  requireCondition(
    exactObject(counts, ["users", "identityArrays", "identities", "emailIdentities"])
      && Object.values(counts).every((value) => Number.isSafeInteger(value) && value >= 0),
    "auth_user_detail_diagnostic_rejected",
  );
  return assertSafeAuthDetailDiagnostic(
    `AUTH_ADMIN_DETAIL_COUNTS|users=${counts.users}|identity_arrays=${counts.identityArrays}|identities=${counts.identities}|email_identities=${counts.emailIdentities}`,
  );
}

function requireDetailedFixtureAdmins(detailedUsers, adminAId, adminBId) {
  requireCondition(
    UUID_PATTERN.test(adminAId)
      && UUID_PATTERN.test(adminBId)
      && adminAId !== adminBId
      && detailedUsers.filter((user) => user.id === adminAId).length === 1
      && detailedUsers.filter((user) => user.id === adminBId).length === 1,
    "auth_user_detail_set_rejected",
  );
  return true;
}

function selectDetailedTargetC(detailedUsers) {
  requireCondition(Array.isArray(detailedUsers), "target_inventory_rejected");
  const targets = detailedUsers.filter(
    (user) => typeof user.email === "string" && TARGET_EMAIL_PATTERN.test(user.email.toLowerCase()),
  );
  requireCondition(targets.length === 1, "target_inventory_rejected");
  return targets[0];
}

function stableValue(value) {
  if (Array.isArray(value)) return value.map(stableValue);
  if (value && typeof value === "object") return Object.fromEntries(Object.keys(value).sort().map((key) => [key, stableValue(value[key])]));
  return value;
}

function authFingerprint(user) {
  requireCondition(user && typeof user === "object" && UUID_PATTERN.test(user.id), "auth_fingerprint_input_invalid");
  const sanitized = {
    id: user.id,
    aud: user.aud ?? null,
    role: user.role ?? null,
    email: user.email ?? null,
    banned_until: user.banned_until ?? null,
    phone_confirmed_at: user.phone_confirmed_at ?? null,
    created_at: user.created_at ?? null,
    updated_at: user.updated_at ?? null,
    app_metadata: user.app_metadata ?? null,
    user_metadata: user.user_metadata ?? null,
    identities: (user.identities ?? []).map((identity) => ({
      id: identity.id ?? null,
      user_id: identity.user_id ?? null,
      provider: identity.provider ?? null,
      identity_data: identity.identity_data ?? null,
      created_at: identity.created_at ?? null,
      updated_at: identity.updated_at ?? null,
    })),
  };
  return sha256Buffer(Buffer.from(JSON.stringify(stableValue(sanitized)), "utf8"));
}

async function exactAdminUser(serviceClient, targetId) {
  const result = await authRequest(() => serviceClient.auth.admin.getUserById(targetId), "auth_target_lookup_failed");
  requireCondition(!result.error && result.data?.user?.id === targetId, "auth_target_lookup_failed");
  return result.data.user;
}

function authBanIsActive(user) {
  const bannedUntil = typeof user?.banned_until === "string" ? Date.parse(user.banned_until) : Number.NaN;
  return Number.isFinite(bannedUntil) && bannedUntil > Date.now();
}

async function updateAuthBan(serviceClient, targetId, banDuration, expectedBanned) {
  requireCondition(banDuration === "876000h" || banDuration === "none", "auth_update_contract_rejected");
  let response = null;
  let requestFailed = false;
  try {
    response = await serviceClient.auth.admin.updateUserById(targetId, { ban_duration: banDuration });
  } catch (error) {
    requestFailed = true;
    void authRequestFailureCode(error, "auth_update_failed");
  }
  const after = await exactAdminUser(serviceClient, targetId);
  requireCondition(authBanIsActive(after) === expectedBanned, "auth_update_not_applied");
  if (!requestFailed && !response?.error) requireCondition(response?.data?.user?.id === targetId, "auth_update_response_malformed");
  return Object.freeze({ classification: !requestFailed && !response?.error ? "confirmed_response" : "response_lost_but_applied", user: after, authCalls: 1 });
}

function lineCollector(onLine) {
  let remainder = "";
  return (chunk) => {
    remainder += chunk.toString("utf8").replace(/\r/g, "");
    const lines = remainder.split("\n");
    remainder = lines.pop() ?? "";
    for (const line of lines) if (line.trim()) onLine(line.trim());
  };
}

function workerApplicationName(name, runDirectory) {
  requireCondition(/^[a-z][a-z0-9_-]{0,39}$/.test(name), "worker_name_rejected");
  const nonce = sha256Buffer(Buffer.from(path.resolve(runDirectory), "utf8")).slice(0, 12);
  const sanitizedName = name.replaceAll("-", "_");
  const applicationName = `sitaa_b3a_${sanitizedName}_${nonce}`;
  requireCondition(applicationName.length <= 63, "worker_application_name_too_long");
  return applicationName;
}

function startPsqlWorker(connection, {
  name,
  runDirectory,
  statementTimeoutMs = 30_000,
  processTimeoutMs = POSTGRES_PROCESS_TIMEOUT_MS,
} = {}) {
  requireCondition(/^[a-z][a-z0-9_-]{0,39}$/.test(name), "worker_name_rejected");
  requireCondition(typeof runDirectory === "string" && path.isAbsolute(runDirectory), "worker_run_directory_rejected");
  const applicationName = workerApplicationName(name, runDirectory);
  const child = spawn(psqlExecutable(), PSQL_ARGUMENTS, {
    cwd: process.env.SITAA_B3A_REPO_ROOT,
    env: postgresChildEnvironment(connection, statementTimeoutMs, process.env, applicationName),
    windowsHide: true,
    stdio: ["pipe", "pipe", "pipe"],
  });
  runtimeState.liveWorkers.add(child);
  const stdoutLines = [];
  let stderr = "";
  let settled = false;
  const waiters = [];
  const consumeLine = (line) => {
    if (stdoutLines.join("\n").length + line.length > POSTGRES_MAX_BUFFER_BYTES) {
      child.kill();
      return;
    }
    stdoutLines.push(line);
    for (const waiter of [...waiters]) {
      if (line.startsWith(waiter.prefix)) {
        waiter.resolve(line);
        waiters.splice(waiters.indexOf(waiter), 1);
      }
    }
  };
  child.stdout.on("data", lineCollector(consumeLine));
  child.stderr.on("data", (chunk) => {
    if (stderr.length < POSTGRES_MAX_BUFFER_BYTES) stderr += chunk.toString("utf8");
  });
  const completion = new Promise((resolve) => {
    const timer = setTimeout(() => {
      if (!settled) child.kill();
    }, processTimeoutMs);
    child.once("error", (error) => {
      settled = true;
      clearTimeout(timer);
      runtimeState.liveWorkers.delete(child);
      resolve({ status: null, error, stderr, stdout: stdoutLines.join("\n"), timedOut: false });
    });
    child.once("close", (status, signal) => {
      if (settled) return;
      settled = true;
      clearTimeout(timer);
      runtimeState.liveWorkers.delete(child);
      resolve({ status, signal, stderr, stdout: stdoutLines.join("\n"), timedOut: signal !== null });
    });
  });
  const waitFor = (prefix, timeoutMs = WORKER_MARKER_TIMEOUT_MS) => new Promise((resolve, reject) => {
    const existing = stdoutLines.find((line) => line.startsWith(prefix));
    if (existing) { resolve(existing); return; }
    const waiter = { prefix, resolve, reject };
    waiters.push(waiter);
    const timer = setTimeout(() => {
      const index = waiters.indexOf(waiter);
      if (index >= 0) waiters.splice(index, 1);
      reject(new SafeFailure("worker_marker_timeout"));
    }, timeoutMs);
    waiter.resolve = (line) => { clearTimeout(timer); resolve(line); };
  });
  return Object.freeze({
    name,
    applicationName,
    write(sql) { requireCondition(!child.stdin.destroyed, "worker_stdin_closed"); child.stdin.write(`${normalizeEol(sql).trim()}\n`); },
    end(sql = null) { if (sql) this.write(sql); child.stdin.end(); },
    waitFor,
    completion,
    stop() { if (!settled) child.kill(); },
  });
}

async function runPsqlWorker(connection, sql, options = {}) {
  const worker = startPsqlWorker(connection, options);
  worker.end(sql);
  return await worker.completion;
}

function writeBarrier(runDirectory, name, value) {
  requireCondition(/^[a-z][a-z0-9-]{0,39}$/.test(name), "barrier_name_rejected");
  const barrierPath = path.join(runDirectory, `${name}.barrier`);
  fs.writeFileSync(barrierPath, `${value}\n`, { encoding: "utf8", flag: "wx" });
  return barrierPath;
}

function barrierTimestamp(line, prefix) {
  const parts = line.split("|");
  requireCondition(parts.length >= 2 && parts[0] === prefix, "worker_marker_shape_rejected");
  const timestamp = parts.at(-1);
  requireCondition(typeof timestamp === "string" && Number.isFinite(Date.parse(timestamp)), "worker_timestamp_rejected");
  return timestamp;
}

function advisoryWaitObservationSql(holderApplicationName, waiterApplicationName) {
  const holder = sqlLiteralText(holderApplicationName);
  const waiter = sqlLiteralText(waiterApplicationName);
  return `
begin;
set transaction read only;
with holder_sessions as (
  select pid,datid from pg_stat_activity where application_name=${holder}
), waiter_sessions as (
  select pid,datid,wait_event_type from pg_stat_activity where application_name=${waiter}
), matching_locks as (
  select 1
  from holder_sessions hs
  join pg_locks hl on hl.pid=hs.pid and hl.locktype='advisory' and hl.granted
  join waiter_sessions ws on true
  join pg_locks wl on wl.pid=ws.pid and wl.locktype='advisory' and not wl.granted
    and wl.database is not distinct from hl.database
    and wl.classid is not distinct from hl.classid
    and wl.objid is not distinct from hl.objid
    and wl.objsubid is not distinct from hl.objsubid
)
select concat_ws('|','ADVISORY_WAIT_OBSERVATION',
  (select count(*) from holder_sessions),
  (select count(*) from waiter_sessions),
  (select count(*) from pg_locks l join holder_sessions h on h.pid=l.pid where l.locktype='advisory' and l.granted),
  (select count(*) from pg_locks l join waiter_sessions w on w.pid=l.pid where l.locktype='advisory' and not l.granted),
  (select count(*) from matching_locks),
  (select count(*) from waiter_sessions where wait_event_type='Lock'));
rollback;`;
}

function advisoryObservationApproved(parts) {
  return Array.isArray(parts)
    && parts.length === 7
    && parts[0] === "ADVISORY_WAIT_OBSERVATION"
    && parts[1] === "1"
    && parts[2] === "1"
    && Number(parts[3]) >= 1
    && Number(parts[4]) >= 1
    && Number(parts[5]) >= 1
    && parts[6] === "1";
}

async function observeAdvisoryLockWait(
  connection,
  holderApplicationName,
  waiterApplicationName,
  {
    timeoutMs = ADVISORY_OBSERVER_TIMEOUT_MS,
    pollMs = ADVISORY_OBSERVER_POLL_MS,
    probe = null,
    now = () => Date.now(),
    pause = (milliseconds) => new Promise((resolve) => setTimeout(resolve, milliseconds)),
  } = {},
) {
  requireCondition(holderApplicationName !== waiterApplicationName, "observer_application_name_duplicated");
  const deadline = now() + timeoutMs;
  const executeProbe = probe ?? (() => executeReadOnlySql(
    connection,
    advisoryWaitObservationSql(holderApplicationName, waiterApplicationName),
    "ADVISORY_WAIT_OBSERVATION",
  ));
  while (now() < deadline) {
    const parts = await executeProbe();
    if (advisoryObservationApproved(parts)) return true;
    await pause(pollMs);
  }
  fail("advisory_observer_timeout");
}

async function coordinateWorkerPair(connection, { holderSql, waiterSql, holderName, waiterName, runDirectory }) {
  const holder = startPsqlWorker(connection, { name: holderName, runDirectory });
  let waiter = null;
  let observationApproved = false;
  try {
    holder.write(holderSql);
    const holderReady = await holder.waitFor("HOLDER_READY|");
    writeBarrier(runDirectory, `${holderName}-ready`, holderReady.split("|").at(-1));
    waiter = startPsqlWorker(connection, { name: waiterName, runDirectory });
    waiter.end(waiterSql);
    const waiterStarted = await waiter.waitFor("WAITER_STARTED|");
    writeBarrier(runDirectory, `${waiterName}-started`, waiterStarted.split("|").at(-1));
    observationApproved = await observeAdvisoryLockWait(
      connection,
      holder.applicationName,
      waiter.applicationName,
    );
    requireCondition(observationApproved, "advisory_wait_not_observed");
    runtimeState.advisoryObservations += 1;
    const holderReleaseSql = `select 'HOLDER_RELEASED|'||clock_timestamp()::text;\ncommit;`;
    holder.end(holderReleaseSql);
    const [holderResult, waiterResult] = await Promise.all([holder.completion, waiter.completion]);
    const holderLines = parsePsqlLines(holderResult);
    const waiterLines = parsePsqlLines(waiterResult);
    const releasedLine = holderLines.find((line) => line.startsWith("HOLDER_RELEASED|"));
    requireCondition(releasedLine, "holder_release_marker_missing");
    const holderReadyAt = barrierTimestamp(holderReady, "HOLDER_READY");
    const waiterStartedAt = barrierTimestamp(waiterStarted, "WAITER_STARTED");
    const holderReleasedAt = barrierTimestamp(releasedLine, "HOLDER_RELEASED");
    requireCondition(Date.parse(waiterStartedAt) < Date.parse(holderReleasedAt), "waiter_not_started_before_release");
    return Object.freeze({
      holderLines,
      waiterLines,
      holderReadyAt,
      waiterStartedAt,
      holderReleasedAt,
      observationApproved,
    });
  } finally {
    if (!observationApproved) {
      holder.stop();
      waiter?.stop();
    }
    holder.stop();
    waiter?.stop();
  }
}

function stopAllWorkers() {
  for (const worker of [...runtimeState.liveWorkers]) {
    try { worker.kill(); } catch { /* limpieza best effort */ }
  }
  runtimeState.liveWorkers.clear();
}

function evidenceHasContradiction(lines) {
  const finalApproved = lines.filter((line) => line === "HOSTED_AUTH_CONCURRENCY_BOUNDARIES|APPROVED").length;
  const finalRejected = lines.filter((line) => line.startsWith("HOSTED_AUTH_CONCURRENCY_BOUNDARIES|REJECTED|")).length;
  return finalApproved > 0 && finalRejected > 0;
}

function writeExclusiveDurable(filePath, lines) {
  requireCondition(!evidenceHasContradiction(lines), "evidence_approved_rejected_conflict");
  for (const line of lines) assertSafeEvidenceLine(line);
  const descriptor = fs.openSync(filePath, "wx");
  try {
    fs.writeFileSync(descriptor, `${lines.join("\n")}\n`, { encoding: "utf8" });
    fs.fsyncSync(descriptor);
  } finally {
    fs.closeSync(descriptor);
  }
}

function publishEvidencePair(
  evidencePath,
  postcheckPath,
  evidenceLines,
  postcheckLines,
  { interruptAt = null } = {},
) {
  requireCondition(!fs.existsSync(evidencePath) && !fs.existsSync(postcheckPath), "evidence_already_exists");
  requireCondition(
    interruptAt === null || interruptAt === "before_postcheck" || interruptAt === "after_postcheck",
    "evidence_interrupt_fixture_rejected",
  );
  const suffix = crypto.randomUUID().replaceAll("-", "");
  const evidenceTemp = `${evidencePath}.${suffix}.next`;
  const postcheckTemp = `${postcheckPath}.${suffix}.next`;
  try {
    writeExclusiveDurable(evidenceTemp, evidenceLines);
    writeExclusiveDurable(postcheckTemp, postcheckLines);
    if (interruptAt === "before_postcheck") fail("evidence_pair_interrupted_before_postcheck");
    fs.renameSync(postcheckTemp, postcheckPath);
    if (interruptAt === "after_postcheck") fail("evidence_pair_interrupted_after_postcheck");
    fs.renameSync(evidenceTemp, evidencePath);
  } catch (error) {
    if (fs.existsSync(evidenceTemp)) fs.unlinkSync(evidenceTemp);
    if (fs.existsSync(postcheckTemp)) fs.unlinkSync(postcheckTemp);
    throw error;
  }
  requireCondition(fs.existsSync(evidencePath) && fs.existsSync(postcheckPath), "evidence_pair_publication_rejected");
}

function publishPartialEvidence(evidencePath, lines) {
  requireCondition(!fs.existsSync(evidencePath), "partial_evidence_already_exists");
  const temp = `${evidencePath}.${crypto.randomUUID().replaceAll("-", "")}.next`;
  try {
    writeExclusiveDurable(temp, lines);
    fs.renameSync(temp, evidencePath);
  } finally {
    if (fs.existsSync(temp)) fs.unlinkSync(temp);
  }
}

function recordApprovedPhase(marker) {
  requireCondition(
    /^[A-Z][A-Z0-9_]{0,79}\|APPROVED$/.test(marker)
      && marker !== "HOSTED_AUTH_CONCURRENCY_BOUNDARIES|APPROVED",
    "approved_phase_marker_rejected",
  );
  if (!runtimeState.approvedPhases.includes(marker)) runtimeState.approvedPhases.push(marker);
}

function isRecoverableV3Postcheck(filePath) {
  const lines = normalizeEol(readRequiredText(filePath, "orphan_postcheck_read_failed"))
    .split("\n").map((line) => line.trim()).filter(Boolean);
  try {
    for (const line of lines) assertSafeEvidenceLine(line);
  } catch {
    return false;
  }
  return lines.filter((line) => line === `HARNESS_VERSION|${HARNESS_VERSION}`).length === 1
    && lines.filter((line) => line === "HOSTED_AUTH_CONCURRENCY_BOUNDARIES_POSTCHECK|APPROVED").length === 1
    && lines.includes("AUTH_HANDLER_STATE|CANONICAL")
    && lines.includes("READ_ONLY_TRANSACTION|true")
    && lines.includes("ROLLBACK|true")
    && !lines.includes("HOSTED_AUTH_CONCURRENCY_BOUNDARIES|APPROVED")
    && !lines.some((line) => line.startsWith("HOSTED_AUTH_CONCURRENCY_BOUNDARIES|REJECTED|"));
}

function reconcileEvidencePublication(
  evidencePath,
  postcheckPath,
  { recoverOrphanPostcheck = false, unlinkFile = fs.unlinkSync } = {},
) {
  requireCondition(typeof unlinkFile === "function", "evidence_reconciliation_unlink_rejected");
  const hasEvidence = fs.existsSync(evidencePath);
  const hasPostcheck = fs.existsSync(postcheckPath);
  if (hasEvidence && !hasPostcheck) fail("committed_evidence_without_postcheck");
  if (hasEvidence && hasPostcheck) fail("concurrency_evidence_already_exists");
  if (!hasEvidence && hasPostcheck) {
    requireCondition(isRecoverableV3Postcheck(postcheckPath), "unrecognized_orphan_postcheck");
    requireCondition(recoverOrphanPostcheck, "orphan_postcheck_recovery_not_allowed");
    unlinkFile(postcheckPath);
  }
  const directory = path.dirname(evidencePath);
  const names = fs.readdirSync(directory);
  requireCondition(
    !names.some((name) => name.startsWith("b3a_matrix_hosted_auth_concurrency_boundaries") && name.includes(".next")),
    "concurrency_evidence_temporary_present",
  );
  requireCondition(!fs.existsSync(evidencePath) && !fs.existsSync(postcheckPath), "evidence_reconciliation_failed");
}

function exactAuthUsersTriggerContractSql() {
  return `(
    (select count(*) from pg_trigger trigger_definition
      where trigger_definition.tgrelid='auth.users'::regclass
        and not trigger_definition.tgisinternal)=2
    and (select count(*) from pg_trigger trigger_definition
      where trigger_definition.tgrelid='auth.users'::regclass
        and not trigger_definition.tgisinternal
        and trigger_definition.tgname='on_sitaa_auth_user_created'
        and trigger_definition.tgenabled='O'
        and trigger_definition.tgfoid='public.handle_sitaa_auth_user_created()'::regprocedure
        and trigger_definition.tgtype=5::smallint
        and cardinality(trigger_definition.tgattr::smallint[])=0
        and trigger_definition.tgqual is null)=1
    and (select count(*) from pg_trigger trigger_definition
      where trigger_definition.tgrelid='auth.users'::regclass
        and not trigger_definition.tgisinternal
        and trigger_definition.tgname='on_sitaa_auth_user_email_changed'
        and trigger_definition.tgenabled='O'
        and trigger_definition.tgfoid='public.sync_sitaa_profile_email_from_auth()'::regprocedure
        and trigger_definition.tgtype=17::smallint
        and cardinality(trigger_definition.tgattr::smallint[])=1
        and trigger_definition.tgqual is not null
        and (select count(*) from unnest(trigger_definition.tgattr::smallint[]) update_attribute(attnum)
          join pg_attribute attribute_definition
            on attribute_definition.attrelid=trigger_definition.tgrelid
           and attribute_definition.attnum=update_attribute.attnum
           and attribute_definition.attname='email'
           and not attribute_definition.attisdropped)=1
        and regexp_replace(
          split_part(split_part(lower(pg_get_triggerdef(trigger_definition.oid,false)),' after ',2),' on ',1),
          '[[:space:]]+',
          '',
          'g'
        )='updateofemail'
        and regexp_replace(regexp_replace(
          split_part(split_part(lower(pg_get_triggerdef(trigger_definition.oid,false)),' when ',2),' execute function ',1),
          '[[:space:]()]',
          '',
          'g'
        ),'::text','','g')='old.emailisdistinctfromnew.email')=1
    and not exists(
      select 1 from pg_trigger trigger_definition
      where not trigger_definition.tgisinternal
        and trigger_definition.tgfoid in (
          'public.handle_sitaa_auth_user_created()'::regprocedure,
          'public.sync_sitaa_profile_email_from_auth()'::regprocedure
        )
        and not (
          trigger_definition.tgrelid='auth.users'::regclass
          and (
            (trigger_definition.tgname='on_sitaa_auth_user_created'
              and trigger_definition.tgfoid='public.handle_sitaa_auth_user_created()'::regprocedure)
            or (trigger_definition.tgname='on_sitaa_auth_user_email_changed'
              and trigger_definition.tgfoid='public.sync_sitaa_profile_email_from_auth()'::regprocedure)
          )
        )
    )
  )`;
}

function authHandlerContractSql(prefix) {
  return `
begin;
set transaction read only;
with handler as (
  select p.*,l.lanname
  from pg_proc p join pg_language l on l.oid=p.prolang
  where p.oid=to_regprocedure(${sqlLiteralText(EXPECTED_AUTH_HANDLER_SIGNATURE)})
)
select concat_ws('|',${sqlLiteralText(prefix)},
  (select count(*) from handler),
  (select count(*) from handler where pg_get_userbyid(proowner)='postgres'),
  (select count(*) from handler where prosecdef),
  (select count(*) from handler where provolatile::text='v'),
  (select count(*) from handler where proconfig=array['search_path=pg_catalog, public, auth']::text[]),
  (select count(*) from handler where proacl::text=${sqlLiteralText(EXPECTED_AUTH_HANDLER_ACL)}),
  (select count(*) from handler where md5(pg_get_functiondef(oid))=${sqlLiteralText(EXPECTED_AUTH_HANDLER_MD5)}),
  (select case when ${exactAuthUsersTriggerContractSql()} then 1 else 0 end));
rollback;`;
}

function authHandlerFixtureApproved(contract) {
  return exactObject(contract, ["signature", "owner", "securityDefiner", "volatility", "searchPath", "acl", "definitionMd5", "triggers"])
    && contract.signature === EXPECTED_AUTH_HANDLER_SIGNATURE
    && contract.owner === "postgres"
    && contract.securityDefiner === true
    && contract.volatility === "v"
    && contract.searchPath === "pg_catalog, public, auth"
    && contract.acl === EXPECTED_AUTH_HANDLER_ACL
    && contract.definitionMd5 === EXPECTED_AUTH_HANDLER_MD5
    && contract.triggers === "exact";
}

function parseAuthHandlerContract(parts, prefix) {
  requireCondition(
    Array.isArray(parts)
      && parts.length === 9
      && parts[0] === prefix
      && parts.slice(1).every((value) => value === "1"),
    "auth_handler_contract_rejected",
  );
  return true;
}

function baselineSql(adminAId, adminBId) {
  const adminA = sqlLiteralUuid(adminAId);
  const adminB = sqlLiteralUuid(adminBId);
  const allActions = B3A_ALL_ACTIONS.map(sqlLiteralText).join(",");
  const authActions = B3A_AUTH_ACTIONS.map(sqlLiteralText).join(",");
  return `
begin;
set transaction read only;
with expected_functions(signature,body_hash,volatility,grantees) as (values
  ('guard_admin_auth_operation_b3a()','b4f997c0089a103737539c380c0c05d1','v','postgres'),
  ('get_admin_account_auth_lifecycle_context_b3a(uuid)','44fd317ebc207cbf572551835fb9be7d','s','authenticated,postgres'),
  ('prepare_admin_account_auth_lifecycle_b3a(uuid,text,text,uuid)','2d8d580677411110fb9255fcced4c715','v','authenticated,postgres'),
  ('claim_admin_auth_operation_b3a(uuid,uuid)','f100545d885836bdfcc6c6f71063f709','v','postgres,service_role'),
  ('record_admin_auth_operation_result_b3a(uuid,uuid,integer,text,text)','0aa2e5f2d1399b086b7223dc7193c61a','v','postgres,service_role'),
  ('finalize_admin_account_auth_reactivation_b3a(uuid)','496707f95d11ca6d9b75c1b3f43a3c6b','v','authenticated,postgres')
), function_contracts as (
  select expected.signature,
    p.oid is not null
    and pg_get_userbyid(p.proowner)='postgres'
    and l.lanname='plpgsql'
    and p.prosecdef
    and p.proconfig=array['search_path=pg_catalog, public']::text[]
    and p.provolatile::text=expected.volatility
    and md5(regexp_replace(p.prosrc,'\\s+','','g'))=expected.body_hash
    and coalesce((select string_agg(pg_get_userbyid(acl.grantee),',' order by pg_get_userbyid(acl.grantee))
      from aclexplode(coalesce(p.proacl,acldefault('f',p.proowner))) acl
      where acl.privilege_type='EXECUTE' and not acl.is_grantable),'')=expected.grantees
    and not exists(select 1 from aclexplode(coalesce(p.proacl,acldefault('f',p.proowner))) acl
      where acl.privilege_type<>'EXECUTE' or acl.is_grantable) as valid
  from expected_functions expected
  left join pg_proc p on p.oid=to_regprocedure('public.'||expected.signature)
  left join pg_language l on l.oid=p.prolang
), target as (
  select u.id
  from auth.users u
  where lower(u.email) ~ '${TARGET_EMAIL_SQL_PATTERN}'
), auth_trigger_contract as (
  select count(*)::bigint as valid
  from pg_trigger t
  join (values
    ('on_sitaa_auth_user_created','public.handle_sitaa_auth_user_created()'::regprocedure),
    ('on_sitaa_auth_user_email_changed','public.sync_sitaa_profile_email_from_auth()'::regprocedure)
  ) expected(name,function_oid) on expected.name=t.tgname and expected.function_oid=t.tgfoid
  where t.tgrelid='auth.users'::regclass and not t.tgisinternal and t.tgenabled='O'
)
select concat_ws('|','CONCURRENCY_BOUNDARIES_BASELINE',
  (select count(*) from auth.users),
  (select count(*) from auth.identities),
  (select count(*) from public.profiles),
  (select count(*) from public.role_assignments),
  (select count(*) from public.profiles p where p.id in (${adminA},${adminB})
    and p.account_status='active' and p.is_active and public.is_exact_b1_account_admin_profile_b2b(p.id)),
  (select count(*) from target),
  (select count(*) from auth.identities i join target t on t.id=i.user_id and i.provider='email'),
  (select count(*) from public.profiles p join target t on t.id=p.id
    where p.account_kind='technical' and p.account_status='active' and p.is_active
      and p.first_names=${sqlLiteralText(TARGET_FIRST_NAMES)} and p.activated_at is not null and p.deactivated_at is null),
  (select count(*) from auth.users u join target t on t.id=u.id
    where u.email_confirmed_at is not null and (u.banned_until is null or u.banned_until<=clock_timestamp())),
  (select count(*) from public.role_assignments r join target t on t.id=r.user_id),
  (select count(*) from public.admin_auth_operations),
  (select count(*) from public.admin_auth_operations where status='succeeded' and completed_stage='completed'),
  (select count(*) from public.admin_auth_operations where status in ('open','processing','retryable_failure')),
  (select count(*) from public.admin_auth_operations where status<>'succeeded'),
  (select count(*) from public.admin_audit_events where action_code in (${allActions})),
  (select count(*) from public.admin_audit_events where action_code in (${authActions}) and outcome='failure'),
  (select count(*) from public.admin_audit_events where action_code in ('account_auth_suspended','account_auth_restored') and outcome='success'),
  (select count(*) from function_contracts where valid),
  (select count(*) from function_contracts),
  (select count(*) from pg_trigger t where t.tgrelid='public.admin_auth_operations'::regclass
    and not t.tgisinternal and t.tgenabled='O' and t.tgfoid='public.guard_admin_auth_operation_b3a()'::regprocedure),
  (select valid from auth_trigger_contract),
  (select case when c.relrowsecurity and not c.relforcerowsecurity then 1 else 0 end
    from pg_class c where c.oid='public.admin_auth_operations'::regclass),
  (select count(*) from pg_policies where schemaname='public' and tablename='admin_auth_operations'),
  (select count(*) from public.profiles where id=${adminA} and account_status='active' and is_active),
  (select count(*) from public.profiles where id=${adminB} and account_status='active' and is_active),
  coalesce((select md5(string_agg(to_jsonb(r)::text,'|' order by r.id)) from public.role_assignments r where r.user_id in (${adminA},${adminB})),''),
  coalesce((select p.activated_at::text from public.profiles p join target t on t.id=p.id),''),
  coalesce((select md5(string_agg(to_jsonb(i)::text,'|' order by i.id)) from auth.identities i join target t on t.id=i.user_id),'')
);
rollback;`;
}

function parseBaseline(parts) {
  requireCondition(Array.isArray(parts) && parts.length === 29 && parts[0] === "CONCURRENCY_BOUNDARIES_BASELINE", "baseline_shape_rejected");
  const aggregates = parseNumericAggregate(parts.slice(1, 26), BASELINE_AGGREGATE_FIELDS, "baseline_counts_rejected");
  requireBaselineAggregates(aggregates);
  requireCondition(/^[0-9a-f]{32}$/.test(parts[26]), "baseline_assignment_hash_rejected");
  requireCondition(Number.isFinite(Date.parse(parts[27])), "baseline_activation_timestamp_rejected");
  requireCondition(/^[0-9a-f]{32}$/.test(parts[28]), "baseline_identity_hash_rejected");
  return Object.freeze({
    aggregates,
    adminAssignmentHash: parts[26],
    targetActivatedAt: parts[27],
    targetIdentityHash: parts[28],
  });
}

function parseFinalPostcheck(parts) {
  requireCondition(
    Array.isArray(parts) && parts.length === 26 && parts[0] === "CONCURRENCY_BOUNDARIES_POSTCHECK",
    "final_postcheck_rejected",
  );
  const aggregates = parseNumericAggregate(
    parts.slice(1),
    FINAL_POSTCHECK_AGGREGATE_FIELDS,
    "final_postcheck_rejected",
  );
  requireFinalPostcheckAggregates(aggregates);
  return aggregates;
}

function syntheticInstitutionalIdentifier(prefix) {
  requireCondition(prefix === "7" || prefix === "8", "case17_identifier_prefix_rejected");
  const digits = Array.from({ length: 24 }, () => crypto.randomInt(0, 10)).join("");
  return `${prefix}${digits}`;
}

function case17InstitutionalIdentifiersFromSql(sql) {
  const normalized = normalizeEol(sql);
  const match = normalized.match(
    /'b3a-student-'\|\|substr\(replace\(gen_random_uuid\(\)::text,'-',''\),1,20\)\|\|'@example\.invalid',\n\s*'(\d+)'::text,\n\s*'(\d+)'::text,/,
  );
  requireCondition(match !== null, "case17_identifier_sql_contract_rejected");
  return Object.freeze({ professor: match[1], student: match[2] });
}

function assertCase17ProfileContract(sql) {
  const normalized = normalizeEol(sql);
  const identifiers = case17InstitutionalIdentifiersFromSql(normalized);
  requireCondition(!normalized.includes("person_type='worker'"), "case17_worker_person_type_rejected");
  requireCondition(
    /person_type='professor',[\s\S]*?institutional_id_type='worker_number',institutional_id_value=c\.professor_identifier/.test(normalized),
    "case17_professor_profile_contract_rejected",
  );
  requireCondition(
    /person_type='student',[\s\S]*?institutional_id_type='student_account',institutional_id_value=c\.student_identifier/.test(normalized),
    "case17_student_profile_contract_rejected",
  );
  requireCondition(
    /^[0-9]{1,50}$/.test(identifiers.professor)
      && /^[0-9]{1,50}$/.test(identifiers.student)
      && identifiers.professor !== identifiers.student,
    "case17_identifier_value_rejected",
  );
  return normalized;
}

const CASE17_LEDGER_HASH_COMPARISON = "md5(coalesce((select string_agg(to_jsonb(o)::text,'|' order by o.id) from public.admin_auth_operations o),''))=(select ledger_hash from sitaa_b3a_case17_context)";
const CASE17_AUDIT_HASH_COMPARISON = "md5(coalesce((select string_agg(to_jsonb(a)::text,'|' order by a.id) from public.admin_audit_events a),''))=(select audit_hash from sitaa_b3a_case17_context)";

function assertCase17HashComparisonContract(sql) {
  const normalized = normalizeEol(sql);
  requireCondition(
    normalized.split(CASE17_LEDGER_HASH_COMPARISON).length - 1 === 1
      && normalized.split(CASE17_AUDIT_HASH_COMPARISON).length - 1 === 1,
    "case17_hash_comparison_contract_rejected",
  );
  return normalized;
}

function case17OrdinaryUsersSql() {
  const professorIdentifier = syntheticInstitutionalIdentifier("7");
  const studentIdentifier = syntheticInstitutionalIdentifier("8");
  const sql = `
begin;
create temporary table sitaa_b3a_case17_context(
  run_marker text not null,
  program_id uuid not null,
  professor_id uuid not null,
  student_id uuid not null,
  professor_email text not null,
  student_email text not null,
  professor_identifier text not null,
  student_identifier text not null,
  ledger_hash text not null,
  audit_hash text not null
) on commit drop;
insert into sitaa_b3a_case17_context
select substr(replace(gen_random_uuid()::text,'-',''),1,12),p.id,gen_random_uuid(),gen_random_uuid(),
  'b3a-professor-'||substr(replace(gen_random_uuid()::text,'-',''),1,20)||'@example.invalid',
  'b3a-student-'||substr(replace(gen_random_uuid()::text,'-',''),1,20)||'@example.invalid',
  ${sqlLiteralText(professorIdentifier)},
  ${sqlLiteralText(studentIdentifier)},
  md5(coalesce((select string_agg(to_jsonb(o)::text,'|' order by o.id) from public.admin_auth_operations o),'')),
  md5(coalesce((select string_agg(to_jsonb(a)::text,'|' order by a.id) from public.admin_audit_events a),''))
from public.academic_programs p where p.is_active order by p.id limit 1;
do $$ begin
  if (select count(*) from sitaa_b3a_case17_context)<>1 then raise exception 'case17_program_missing'; end if;
end $$;
create temporary table sitaa_b3a_case17_outcomes(actor_type text not null,test_name text not null,primary key(actor_type,test_name)) on commit drop;
create function pg_temp.case17_actor_id(actor_type text) returns uuid language sql stable set search_path=pg_temp as $$
  select case actor_type when 'professor' then professor_id when 'student' then student_id end from sitaa_b3a_case17_context
$$;
create function pg_temp.case17_other_id(actor_type text) returns uuid language sql stable set search_path=pg_temp as $$
  select case actor_type when 'professor' then student_id when 'student' then professor_id end from sitaa_b3a_case17_context
$$;
create function pg_temp.case17_set_actor(actor_type text) returns void language plpgsql set search_path=pg_temp,pg_catalog as $$
declare actor_id uuid:=pg_temp.case17_actor_id(actor_type);
begin
  perform set_config('request.jwt.claim.sub',actor_id::text,true);
  perform set_config('request.jwt.claims',jsonb_build_object('sub',actor_id,'role','authenticated')::text,true);
end $$;
insert into auth.users(id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at)
select professor_id,'authenticated','authenticated',professor_email,'',clock_timestamp(),
  jsonb_build_object('provider','google','providers',jsonb_build_array('google')),
  jsonb_build_object('name','Profesor sintético B3a'),clock_timestamp(),clock_timestamp()
from sitaa_b3a_case17_context;
insert into auth.users(id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at)
select student_id,'authenticated','authenticated',student_email,'',clock_timestamp(),
  jsonb_build_object('provider','google','providers',jsonb_build_array('google')),
  jsonb_build_object('name','Alumno sintético B3a'),clock_timestamp(),clock_timestamp()
from sitaa_b3a_case17_context;
update public.profiles p set first_names='Profesor',paternal_surname='Sintético',maternal_surname=null,
  full_name='Profesor Sintético',account_status='active',person_type='professor',
  primary_program_id=c.program_id,institutional_id_type='worker_number',institutional_id_value=c.professor_identifier,
  is_active=true,activated_at=clock_timestamp(),deactivated_at=null
from sitaa_b3a_case17_context c where p.id=c.professor_id;
update public.profiles p set first_names='Alumno',paternal_surname='Sintético',maternal_surname=null,
  full_name='Alumno Sintético',account_status='active',person_type='student',
  primary_program_id=c.program_id,institutional_id_type='student_account',institutional_id_value=c.student_identifier,
  is_active=true,activated_at=clock_timestamp(),deactivated_at=null
from sitaa_b3a_case17_context c where p.id=c.student_id;
grant select on pg_temp.sitaa_b3a_case17_context to authenticated;
grant insert,select on pg_temp.sitaa_b3a_case17_outcomes to authenticated;
grant execute on function pg_temp.case17_actor_id(text),pg_temp.case17_other_id(text),pg_temp.case17_set_actor(text) to authenticated;

set local role authenticated;
select pg_temp.case17_set_actor('professor');
do $professor$
declare actor_type constant text:='professor';
begin
  begin perform * from public.prepare_admin_account_auth_lifecycle_b3a(pg_temp.case17_other_id(actor_type),'deactivate','Motivo sintético de profesor',gen_random_uuid()); raise exception 'case17_prepare_unexpected'; exception when insufficient_privilege then if sqlerrm<>'sitaa_admin_access_denied' then raise; end if; insert into pg_temp.sitaa_b3a_case17_outcomes values(actor_type,'prepare'); end;
  begin perform * from public.prepare_admin_account_auth_lifecycle_b3a(pg_temp.case17_actor_id(actor_type),'deactivate','Otro request sintético',gen_random_uuid()); raise exception 'case17_other_request_unexpected'; exception when insufficient_privilege then if sqlerrm<>'sitaa_admin_access_denied' then raise; end if; insert into pg_temp.sitaa_b3a_case17_outcomes values(actor_type,'other_request'); end;
  begin perform * from public.get_admin_account_auth_lifecycle_context_b3a(pg_temp.case17_other_id(actor_type)); raise exception 'case17_context_unexpected'; exception when insufficient_privilege then insert into pg_temp.sitaa_b3a_case17_outcomes values(actor_type,'context'); end;
  begin perform * from public.finalize_admin_account_auth_reactivation_b3a(gen_random_uuid()); raise exception 'case17_finalize_unexpected'; exception when insufficient_privilege then insert into pg_temp.sitaa_b3a_case17_outcomes values(actor_type,'finalize'); end;
  begin perform * from public.claim_admin_auth_operation_b3a(gen_random_uuid(),pg_temp.case17_actor_id(actor_type)); raise exception 'case17_claim_unexpected'; exception when insufficient_privilege then insert into pg_temp.sitaa_b3a_case17_outcomes values(actor_type,'claim'); end;
  begin perform * from public.record_admin_auth_operation_result_b3a(gen_random_uuid(),pg_temp.case17_actor_id(actor_type),1,'retryable_failure','auth_temporarily_unavailable'); raise exception 'case17_record_unexpected'; exception when insufficient_privilege then insert into pg_temp.sitaa_b3a_case17_outcomes values(actor_type,'record'); end;
  begin perform 1 from public.admin_auth_operations; raise exception 'case17_select_unexpected'; exception when insufficient_privilege then insert into pg_temp.sitaa_b3a_case17_outcomes values(actor_type,'select'); end;
  begin insert into public.admin_auth_operations(request_id,requested_by_profile_id,target_profile_id,operation_code,reason) values(gen_random_uuid(),pg_temp.case17_actor_id(actor_type),pg_temp.case17_other_id(actor_type),'deactivate','Intento directo'); raise exception 'case17_insert_unexpected'; exception when insufficient_privilege then insert into pg_temp.sitaa_b3a_case17_outcomes values(actor_type,'insert'); end;
  begin update public.admin_auth_operations set updated_at=updated_at; raise exception 'case17_update_unexpected'; exception when insufficient_privilege then insert into pg_temp.sitaa_b3a_case17_outcomes values(actor_type,'update'); end;
  begin delete from public.admin_auth_operations; raise exception 'case17_delete_unexpected'; exception when insufficient_privilege then insert into pg_temp.sitaa_b3a_case17_outcomes values(actor_type,'delete'); end;
  begin perform public.guard_admin_auth_operation_b3a(); raise exception 'case17_private_unexpected'; exception when insufficient_privilege then insert into pg_temp.sitaa_b3a_case17_outcomes values(actor_type,'private'); end;
end;
$professor$;
select pg_temp.case17_set_actor('student');
do $student$
declare actor_type constant text:='student';
begin
  begin perform * from public.prepare_admin_account_auth_lifecycle_b3a(pg_temp.case17_other_id(actor_type),'deactivate','Motivo sintético de alumno',gen_random_uuid()); raise exception 'case17_prepare_unexpected'; exception when insufficient_privilege then if sqlerrm<>'sitaa_admin_access_denied' then raise; end if; insert into pg_temp.sitaa_b3a_case17_outcomes values(actor_type,'prepare'); end;
  begin perform * from public.prepare_admin_account_auth_lifecycle_b3a(pg_temp.case17_actor_id(actor_type),'deactivate','Otro request sintético',gen_random_uuid()); raise exception 'case17_other_request_unexpected'; exception when insufficient_privilege then if sqlerrm<>'sitaa_admin_access_denied' then raise; end if; insert into pg_temp.sitaa_b3a_case17_outcomes values(actor_type,'other_request'); end;
  begin perform * from public.get_admin_account_auth_lifecycle_context_b3a(pg_temp.case17_other_id(actor_type)); raise exception 'case17_context_unexpected'; exception when insufficient_privilege then insert into pg_temp.sitaa_b3a_case17_outcomes values(actor_type,'context'); end;
  begin perform * from public.finalize_admin_account_auth_reactivation_b3a(gen_random_uuid()); raise exception 'case17_finalize_unexpected'; exception when insufficient_privilege then insert into pg_temp.sitaa_b3a_case17_outcomes values(actor_type,'finalize'); end;
  begin perform * from public.claim_admin_auth_operation_b3a(gen_random_uuid(),pg_temp.case17_actor_id(actor_type)); raise exception 'case17_claim_unexpected'; exception when insufficient_privilege then insert into pg_temp.sitaa_b3a_case17_outcomes values(actor_type,'claim'); end;
  begin perform * from public.record_admin_auth_operation_result_b3a(gen_random_uuid(),pg_temp.case17_actor_id(actor_type),1,'retryable_failure','auth_temporarily_unavailable'); raise exception 'case17_record_unexpected'; exception when insufficient_privilege then insert into pg_temp.sitaa_b3a_case17_outcomes values(actor_type,'record'); end;
  begin perform 1 from public.admin_auth_operations; raise exception 'case17_select_unexpected'; exception when insufficient_privilege then insert into pg_temp.sitaa_b3a_case17_outcomes values(actor_type,'select'); end;
  begin insert into public.admin_auth_operations(request_id,requested_by_profile_id,target_profile_id,operation_code,reason) values(gen_random_uuid(),pg_temp.case17_actor_id(actor_type),pg_temp.case17_other_id(actor_type),'deactivate','Intento directo'); raise exception 'case17_insert_unexpected'; exception when insufficient_privilege then insert into pg_temp.sitaa_b3a_case17_outcomes values(actor_type,'insert'); end;
  begin update public.admin_auth_operations set updated_at=updated_at; raise exception 'case17_update_unexpected'; exception when insufficient_privilege then insert into pg_temp.sitaa_b3a_case17_outcomes values(actor_type,'update'); end;
  begin delete from public.admin_auth_operations; raise exception 'case17_delete_unexpected'; exception when insufficient_privilege then insert into pg_temp.sitaa_b3a_case17_outcomes values(actor_type,'delete'); end;
  begin perform public.guard_admin_auth_operation_b3a(); raise exception 'case17_private_unexpected'; exception when insufficient_privilege then insert into pg_temp.sitaa_b3a_case17_outcomes values(actor_type,'private'); end;
end;
$student$;
reset role;
select concat_ws('|','CASE17_SQL',
  (select count(*) from sitaa_b3a_case17_outcomes where actor_type='professor'),
  (select count(*) from sitaa_b3a_case17_outcomes where actor_type='student'),
  (select case when md5(coalesce((select string_agg(to_jsonb(o)::text,'|' order by o.id) from public.admin_auth_operations o),''))=(select ledger_hash from sitaa_b3a_case17_context) then 1 else 0 end),
  (select case when md5(coalesce((select string_agg(to_jsonb(a)::text,'|' order by a.id) from public.admin_audit_events a),''))=(select audit_hash from sitaa_b3a_case17_context) then 1 else 0 end));
rollback;`;
  return assertCase17HashComparisonContract(assertCase17ProfileContract(sql));
}

function assertCase18AclContract(sql, postgrestSource = verifyServiceRolePostgrestBoundary.toString()) {
  const normalizedSql = normalizeEol(sql);
  const normalizedPostgrest = normalizeEol(postgrestSource);
  requireCondition(
    normalizedSql.includes("perform 1 from public.admin_audit_events where false")
      && normalizedSql.includes("values('audit_select')")
      && normalizedSql.includes("privilege_type in ('SELECT','INSERT')")
      && normalizedSql.includes("attacl is not null")
      && !normalizedSql.includes("case18_audit_unexpected")
      && normalizedPostgrest.includes('select("id", { head: true }).limit(0)')
      && normalizedPostgrest.includes("service_audit_select_not_allowed")
      && !normalizedPostgrest.includes("service_audit_select_not_denied"),
    "case18_audit_acl_contract_rejected",
  );
  return normalizedSql;
}

function case18ServiceRoleSql(adminProfileId, targetProfileId) {
  // "Sólo claim y record" se limita a las RPC B.3a y al ledger; la bitácora histórica
  // conserva su contrato append-only SELECT/INSERT para service_role.
  const admin = sqlLiteralUuid(adminProfileId);
  const target = sqlLiteralUuid(targetProfileId);
  const sql = `
begin;
create temporary table sitaa_b3a_case18_outcomes(test_name text primary key) on commit drop;
grant insert,select on pg_temp.sitaa_b3a_case18_outcomes to service_role;
set local role service_role;
select set_config('request.jwt.claims',jsonb_build_object('role','service_role')::text,true);
do $service_boundary$
begin
  begin perform 1 from public.admin_auth_operations; raise exception 'case18_select_unexpected'; exception when insufficient_privilege then insert into pg_temp.sitaa_b3a_case18_outcomes values('ledger_select'); end;
  begin insert into public.admin_auth_operations(request_id,requested_by_profile_id,target_profile_id,operation_code,reason) values(gen_random_uuid(),gen_random_uuid(),gen_random_uuid(),'deactivate','Intento service role'); raise exception 'case18_insert_unexpected'; exception when insufficient_privilege then insert into pg_temp.sitaa_b3a_case18_outcomes values('ledger_insert'); end;
  begin update public.admin_auth_operations set updated_at=updated_at; raise exception 'case18_update_unexpected'; exception when insufficient_privilege then insert into pg_temp.sitaa_b3a_case18_outcomes values('ledger_update'); end;
  begin delete from public.admin_auth_operations; raise exception 'case18_delete_unexpected'; exception when insufficient_privilege then insert into pg_temp.sitaa_b3a_case18_outcomes values('ledger_delete'); end;
  begin execute 'truncate table public.admin_auth_operations'; raise exception 'case18_truncate_unexpected'; exception when insufficient_privilege then insert into pg_temp.sitaa_b3a_case18_outcomes values('ledger_truncate'); end;
  perform 1 from public.admin_audit_events where false;
  insert into pg_temp.sitaa_b3a_case18_outcomes values('audit_select');
  insert into public.admin_audit_events(actor_profile_id,target_profile_id,action_code,outcome,reason,metadata)
    values(${admin},${target},'account_auth_suspension_failed','failure','Prueba transaccional ACL service role','{}'::jsonb);
  insert into pg_temp.sitaa_b3a_case18_outcomes values('audit_insert');
  begin update public.admin_audit_events set reason=reason; raise exception 'case18_audit_update_unexpected'; exception when insufficient_privilege then insert into pg_temp.sitaa_b3a_case18_outcomes values('audit_update'); end;
  begin delete from public.admin_audit_events; raise exception 'case18_audit_delete_unexpected'; exception when insufficient_privilege then insert into pg_temp.sitaa_b3a_case18_outcomes values('audit_delete'); end;
  begin execute 'truncate table public.admin_audit_events'; raise exception 'case18_audit_truncate_unexpected'; exception when insufficient_privilege then insert into pg_temp.sitaa_b3a_case18_outcomes values('audit_truncate'); end;
  begin perform public.guard_admin_auth_operation_b3a(); raise exception 'case18_guard_unexpected'; exception when insufficient_privilege then insert into pg_temp.sitaa_b3a_case18_outcomes values('guard'); end;
  begin perform * from public.prepare_admin_account_auth_lifecycle_b3a(gen_random_uuid(),'deactivate','Intento service role',gen_random_uuid()); raise exception 'case18_prepare_unexpected'; exception when insufficient_privilege then insert into pg_temp.sitaa_b3a_case18_outcomes values('prepare'); end;
  begin perform * from public.finalize_admin_account_auth_reactivation_b3a(gen_random_uuid()); raise exception 'case18_finalize_unexpected'; exception when insufficient_privilege then insert into pg_temp.sitaa_b3a_case18_outcomes values('finalize'); end;
  begin perform * from public.get_admin_account_auth_lifecycle_context_b3a(gen_random_uuid()); raise exception 'case18_context_unexpected'; exception when insufficient_privilege then insert into pg_temp.sitaa_b3a_case18_outcomes values('context'); end;
  begin perform * from public.transition_admin_account_lifecycle_b2b(gen_random_uuid(),'inactive','Intento service role'); raise exception 'case18_b2b_unexpected'; exception when insufficient_privilege then insert into pg_temp.sitaa_b3a_case18_outcomes values('b2b_mutator'); end;
end;
$service_boundary$;
reset role;
select concat_ws('|','CASE18_SQL',
  (select count(*) from sitaa_b3a_case18_outcomes),
  (select case when
    (select count(*) from aclexplode(coalesce(c.relacl,acldefault('r',c.relowner))) acl
      where pg_get_userbyid(acl.grantee)='service_role'
        and acl.privilege_type in ('SELECT','INSERT') and not acl.is_grantable)=2
    and not exists(select 1 from aclexplode(coalesce(c.relacl,acldefault('r',c.relowner))) acl
      where pg_get_userbyid(acl.grantee)='service_role'
        and (acl.privilege_type not in ('SELECT','INSERT') or acl.is_grantable))
    then 1 else 0 end from pg_class c where c.oid='public.admin_audit_events'::regclass),
  (select case when not exists(select 1 from pg_attribute a
      where a.attrelid='public.admin_audit_events'::regclass and a.attnum>0 and not a.attisdropped and a.attacl is not null)
    then 1 else 0 end),
  (select case when
    has_function_privilege('service_role','public.claim_admin_auth_operation_b3a(uuid,uuid)','EXECUTE')
    and has_function_privilege('service_role','public.record_admin_auth_operation_result_b3a(uuid,uuid,integer,text,text)','EXECUTE')
    and not has_function_privilege('service_role','public.guard_admin_auth_operation_b3a()','EXECUTE')
    and not has_function_privilege('service_role','public.get_admin_account_auth_lifecycle_context_b3a(uuid)','EXECUTE')
    and not has_function_privilege('service_role','public.prepare_admin_account_auth_lifecycle_b3a(uuid,text,text,uuid)','EXECUTE')
    and not has_function_privilege('service_role','public.finalize_admin_account_auth_reactivation_b3a(uuid)','EXECUTE')
    and not has_function_privilege('service_role','public.transition_admin_account_lifecycle_b2b(uuid,text,text)','EXECUTE')
    then 1 else 0 end),
  (select case when not has_table_privilege('service_role','public.admin_auth_operations','SELECT')
    and not has_table_privilege('service_role','public.admin_auth_operations','INSERT')
    and not has_table_privilege('service_role','public.admin_auth_operations','UPDATE')
    and not has_table_privilege('service_role','public.admin_auth_operations','DELETE')
    and not has_table_privilege('service_role','public.admin_auth_operations','TRUNCATE')
    then 1 else 0 end));
rollback;`;
  return assertCase18AclContract(sql);
}

function createSyntheticAuthoritySql(authorityId, authorityEmail, adminAId) {
  const authority = sqlLiteralUuid(authorityId);
  const email = sqlLiteralText(authorityEmail);
  const adminA = sqlLiteralUuid(adminAId);
  return `
begin;
do $create_authority$
declare assignment_id uuid;
begin
  if exists(select 1 from auth.users where id=${authority} or lower(email)=${email}) then
    raise exception 'synthetic_authority_collision';
  end if;
  insert into auth.users(id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at)
  values(${authority},'authenticated','authenticated',${email},'',clock_timestamp(),
    jsonb_build_object('sitaa_account_kind','technical','sitaa_first_names','Autoridad Sintética D'),
    '{}'::jsonb,clock_timestamp(),clock_timestamp());
  if not exists(select 1 from public.profiles where id=${authority} and account_kind='technical'
    and account_status='active' and is_active and first_names='Autoridad Sintética D') then
    raise exception 'synthetic_authority_profile_invalid';
  end if;
  insert into public.role_assignments(
    user_id,role_code,scope_type,service_area,division_id,program_id,starts_at,ends_at,is_active,assigned_by
  ) values(
    ${authority},'technical_admin','system','technical',null,null,
    public.sitaa_current_mexico_date(),null,false,${adminA}
  ) returning id into assignment_id;
  raise notice 'assignment_created';
end;
$create_authority$;
select concat_ws('|','SYNTHETIC_AUTHORITY_CREATED',
  (select id::text from public.role_assignments where user_id=${authority} and role_code='technical_admin'),
  (select count(*) from public.profiles where id=${authority}),
  (select count(*) from public.role_assignments where user_id=${authority} and not is_active),
  (select count(*) from auth.users where id=${authority} and email_confirmed_at is not null));
commit;`;
}

function setSyntheticAuthoritySql(authorityId, assignmentId, enabled) {
  const authority = sqlLiteralUuid(authorityId);
  const assignment = sqlLiteralUuid(assignmentId);
  const expected = enabled ? "true" : "false";
  return `
begin;
do $$
declare affected integer;
begin
  update public.role_assignments
  set is_active=${expected}
  where id=${assignment} and user_id=${authority} and role_code='technical_admin'
    and scope_type='system' and service_area='technical';
  get diagnostics affected = row_count;
  if affected <> 1 then raise exception 'synthetic_authority_assignment_missing'; end if;
  if public.is_exact_b1_account_admin_profile_b2b(${authority}) is distinct from ${expected} then
    raise exception 'synthetic_authority_state_rejected';
  end if;
end $$;
select concat_ws('|','SYNTHETIC_AUTHORITY_STATE',${sqlLiteralText(enabled ? "enabled" : "disabled")});
commit;`;
}

function operationSnapshotSql(targetId, operationId = null, prefix = "OPERATION_SNAPSHOT") {
  const target = sqlLiteralUuid(targetId);
  const operationPredicate = operationId ? `and o.id=${sqlLiteralUuid(operationId)}` : "";
  const actions = B3A_ALL_ACTIONS.map(sqlLiteralText).join(",");
  return `
begin;
set transaction read only;
select concat_ws('|',${sqlLiteralText(prefix)},
  (select count(*) from public.admin_auth_operations),
  (select count(*) from public.admin_audit_events where action_code in (${actions})),
  coalesce((select md5(string_agg(to_jsonb(o)::text,'|' order by o.id)) from public.admin_auth_operations o where o.target_profile_id=${target} ${operationPredicate}),''),
  coalesce((select md5(string_agg(to_jsonb(a)::text,'|' order by a.id)) from public.admin_audit_events a where a.target_profile_id=${target} and a.action_code in (${actions})),''),
  coalesce((select status from public.admin_auth_operations o where o.target_profile_id=${target} ${operationPredicate} order by requested_at desc,id desc limit 1),''),
  coalesce((select completed_stage from public.admin_auth_operations o where o.target_profile_id=${target} ${operationPredicate} order by requested_at desc,id desc limit 1),''),
  coalesce((select attempt_count::text from public.admin_auth_operations o where o.target_profile_id=${target} ${operationPredicate} order by requested_at desc,id desc limit 1),''),
  coalesce((select processing_started_at::text from public.admin_auth_operations o where o.target_profile_id=${target} ${operationPredicate} order by requested_at desc,id desc limit 1),''),
  coalesce((select updated_at::text from public.admin_auth_operations o where o.target_profile_id=${target} ${operationPredicate} order by requested_at desc,id desc limit 1),''));
rollback;`;
}

function leaseOperationStateSql(operationId, prefix) {
  return `
begin;
set transaction read only;
select concat_ws('|',${sqlLiteralText(prefix)},
  o.id,o.status,o.completed_stage,o.attempt_count,o.processing_started_at,o.updated_at,
  md5(concat_ws('|',
    coalesce(o.profile_audit_event_id::text,''),
    coalesce(o.auth_audit_event_id::text,''),
    coalesce(o.auth_synchronized_at::text,''),
    coalesce(o.completed_at::text,''),
    coalesce(o.last_error_code,''))))
from public.admin_auth_operations o where o.id=${sqlLiteralUuid(operationId)};
rollback;`;
}

function parseLeaseOperationState(parts, prefix, operationId) {
  requireCondition(
    Array.isArray(parts)
      && parts.length === 8
      && parts[0] === prefix
      && parts[1] === operationId
      && parts[2] === "processing"
      && parts[3] === "profile_suspended"
      && /^\d+$/.test(parts[4])
      && Number.isFinite(Date.parse(parts[5]))
      && Number.isFinite(Date.parse(parts[6]))
      && /^[0-9a-f]{32}$/.test(parts[7]),
    "lease_state_rejected",
  );
  return Object.freeze({
    operationId: parts[1],
    status: parts[2],
    stage: parts[3],
    attemptCount: Number(parts[4]),
    processingStartedAt: parts[5],
    updatedAt: parts[6],
    evidenceHash: parts[7],
  });
}

function recoveredLeasePostcheckApproved(before, after, leaseFinishedAt, holderReleasedAt, waiterStartedAt) {
  return before.operationId === after.operationId
    && before.stage === after.stage
    && before.evidenceHash === after.evidenceHash
    && before.attemptCount === 1
    && after.attemptCount === 2
    && Date.parse(after.processingStartedAt) >= Date.parse(leaseFinishedAt)
    && Date.parse(after.processingStartedAt) >= Date.parse(holderReleasedAt)
    && Date.parse(after.processingStartedAt) > Date.parse(waiterStartedAt)
    && Date.parse(after.updatedAt) >= Date.parse(after.processingStartedAt);
}

function profileAndLedgerSnapshotSql(targetId, prefix) {
  const target = sqlLiteralUuid(targetId);
  return `
begin;
set transaction read only;
select concat_ws('|',${sqlLiteralText(prefix)},
  coalesce((select md5(to_jsonb(p)::text) from public.profiles p where p.id=${target}),''),
  coalesce((select md5(string_agg(to_jsonb(o)::text,'|' order by o.id)) from public.admin_auth_operations o),''),
  coalesce((select md5(string_agg(to_jsonb(a)::text,'|' order by a.id)) from public.admin_audit_events a),''));
rollback;`;
}

function holderPrepareSql(adminId, targetId, requestId, transition, reason) {
  return `
begin;
set local role authenticated;
select set_config('request.jwt.claim.sub',${sqlLiteralText(adminId)},true);
select set_config('request.jwt.claims',jsonb_build_object('sub',${sqlLiteralText(adminId)},'role','authenticated')::text,true);
with prepared as (
  select * from public.prepare_admin_account_auth_lifecycle_b3a(
    ${sqlLiteralUuid(targetId)},${sqlLiteralText(transition)},${sqlLiteralText(reason)},${sqlLiteralUuid(requestId)}
  )
)
select 'HOLDER_READY|'||operation_id::text||'|'||clock_timestamp()::text from prepared;`;
}

function waiterPrepareSameSql(adminId, targetId, requestId, transition, reason) {
  return `
begin;
set local role authenticated;
select set_config('request.jwt.claim.sub',${sqlLiteralText(adminId)},true);
select set_config('request.jwt.claims',jsonb_build_object('sub',${sqlLiteralText(adminId)},'role','authenticated')::text,true);
select 'WAITER_STARTED|'||clock_timestamp()::text;
with prepared as (
  select * from public.prepare_admin_account_auth_lifecycle_b3a(
    ${sqlLiteralUuid(targetId)},${sqlLiteralText(transition)},${sqlLiteralText(reason)},${sqlLiteralUuid(requestId)}
  )
)
select 'WAITER_RESULT|'||operation_id::text||'|'||clock_timestamp()::text from prepared;
commit;`;
}

function advisoryHolderSql() {
  return `
begin;
select pg_advisory_xact_lock(1397310529,9002);
select 'HOLDER_READY|LOCK|'||clock_timestamp()::text;`;
}

function waiterPrepareErrorSql(adminId, targetId, requestId, transition, reason, expectedSqlState, expectedMessage, resultMarker) {
  return `
begin;
create temporary table outcome(value text not null) on commit drop;
grant insert,select on pg_temp.outcome to authenticated;
set local role authenticated;
select set_config('request.jwt.claim.sub',${sqlLiteralText(adminId)},true);
select set_config('request.jwt.claims',jsonb_build_object('sub',${sqlLiteralText(adminId)},'role','authenticated')::text,true);
select 'WAITER_STARTED|'||clock_timestamp()::text;
do $waiter_error$
begin
  begin
    perform * from public.prepare_admin_account_auth_lifecycle_b3a(
      ${sqlLiteralUuid(targetId)},${sqlLiteralText(transition)},${sqlLiteralText(reason)},${sqlLiteralUuid(requestId)}
    );
    raise exception 'unexpected_prepare_success';
  exception when others then
    if sqlstate<>${sqlLiteralText(expectedSqlState)} or sqlerrm<>${sqlLiteralText(expectedMessage)} then raise; end if;
    insert into pg_temp.outcome values('approved');
  end;
end;
$waiter_error$;
reset role;
select ${sqlLiteralText(resultMarker)}||'|'||(select value from outcome)||'|'||clock_timestamp()::text;
commit;`;
}

function claimWaiterSql(actorId, operationId) {
  return `
begin;
set local role service_role;
select set_config('request.jwt.claims',jsonb_build_object('role','service_role')::text,true);
select 'WAITER_STARTED|'||clock_timestamp()::text;
create temporary table claim_result on commit drop as
select * from public.claim_admin_auth_operation_b3a(${sqlLiteralUuid(operationId)},${sqlLiteralUuid(actorId)});
reset role;
select concat_ws('|','CLAIM_RESULT',c.operation_id,c.attempt_count,c.claimed,
  o.processing_started_at,o.updated_at,clock_timestamp())
from claim_result c join public.admin_auth_operations o on o.id=c.operation_id;
commit;`;
}

function authorityLossClaimSql(authorityId, operationId, resultMarker) {
  return `
begin;
create temporary table outcome(value text not null) on commit drop;
grant insert,select on pg_temp.outcome to service_role;
set local role service_role;
select set_config('request.jwt.claims',jsonb_build_object('role','service_role')::text,true);
select 'WAITER_STARTED|'||clock_timestamp()::text;
do $authority_loss$
begin
  begin
    perform * from public.claim_admin_auth_operation_b3a(${sqlLiteralUuid(operationId)},${sqlLiteralUuid(authorityId)});
    raise exception 'authority_loss_claim_unexpected';
  exception when insufficient_privilege then
    if sqlerrm<>'sitaa_admin_access_denied' then raise; end if;
    insert into pg_temp.outcome values('approved');
  end;
end;
$authority_loss$;
reset role;
select ${sqlLiteralText(resultMarker)}||'|'||(select value from outcome)||'|'||clock_timestamp()::text;
commit;`;
}

function authorityLossRecordSql(authorityId, operationId, attemptCount) {
  return `
begin;
create temporary table outcome(value text not null) on commit drop;
grant insert,select on pg_temp.outcome to service_role;
set local role service_role;
select set_config('request.jwt.claims',jsonb_build_object('role','service_role')::text,true);
select 'WAITER_STARTED|'||clock_timestamp()::text;
do $authority_loss$
begin
  begin
    perform * from public.record_admin_auth_operation_result_b3a(
      ${sqlLiteralUuid(operationId)},${sqlLiteralUuid(authorityId)},${Number(attemptCount)},'auth_succeeded',null
    );
    raise exception 'authority_loss_record_unexpected';
  exception when insufficient_privilege then
    if sqlerrm<>'sitaa_admin_access_denied' then raise; end if;
    insert into pg_temp.outcome values('approved');
  end;
end;
$authority_loss$;
reset role;
select 'AUTHORITY_LOSS_RECORD_RESULT|'||(select value from outcome)||'|'||clock_timestamp()::text;
commit;`;
}

function leaseWaitSql() {
  return `
begin;
set transaction read only;
set local statement_timeout='330s';
select 'LEASE_WAIT_STARTED|'||clock_timestamp()::text;
select pg_sleep(${LEASE_WAIT_SECONDS});
select 'LEASE_WAIT_FINISHED|'||clock_timestamp()::text;
rollback;`;
}

function createReactivationPrepareSql(adminId, targetId, requestId, reason) {
  return `
begin;
set local role authenticated;
select set_config('request.jwt.claim.sub',${sqlLiteralText(adminId)},true);
select set_config('request.jwt.claims',jsonb_build_object('sub',${sqlLiteralText(adminId)},'role','authenticated')::text,true);
with prepared as (
  select * from public.prepare_admin_account_auth_lifecycle_b3a(
    ${sqlLiteralUuid(targetId)},'reactivate',${sqlLiteralText(reason)},${sqlLiteralUuid(requestId)}
  )
)
select concat_ws('|','REACTIVATION_PREPARED',operation_id,status,completed_stage,attempt_count) from prepared;
commit;`;
}

function finalPostcheckSql(targetId, adminAId, adminBId, authorityId, authorityAssignmentId, baseline) {
  const target = sqlLiteralUuid(targetId);
  const adminA = sqlLiteralUuid(adminAId);
  const adminB = sqlLiteralUuid(adminBId);
  const authority = sqlLiteralUuid(authorityId);
  const assignment = sqlLiteralUuid(authorityAssignmentId);
  const actions = B3A_ALL_ACTIONS.map(sqlLiteralText).join(",");
  const authFailureActions = ["account_auth_suspension_failed", "account_auth_restoration_failed"].map(sqlLiteralText).join(",");
  return `
begin;
set transaction read only;
select concat_ws('|','CONCURRENCY_BOUNDARIES_POSTCHECK',
  (select count(*) from auth.users),
  (select count(*) from auth.identities),
  (select count(*) from public.profiles),
  (select count(*) from public.role_assignments),
  (select count(*) from public.profiles p where p.account_status='active' and p.is_active and public.is_exact_b1_account_admin_profile_b2b(p.id)),
  (select count(*) from public.profiles where id=${target} and account_status='active' and is_active),
  (select count(*) from auth.users where id=${target} and email_confirmed_at is not null and (banned_until is null or banned_until<=clock_timestamp())),
  (select count(*) from public.role_assignments where user_id=${target}),
  (select count(*) from public.admin_auth_operations),
  (select count(*) from public.admin_auth_operations where status='succeeded' and completed_stage='completed'),
  (select count(*) from public.admin_auth_operations where status in ('open','processing','retryable_failure')),
  (select count(*) from public.admin_auth_operations where status<>'succeeded'),
  (select count(*) from public.admin_audit_events where action_code in (${actions})),
  (select count(*) from public.admin_audit_events where action_code in (${authFailureActions}) and outcome='failure'),
  (select count(*) from public.admin_audit_events where action_code in ('account_auth_suspended','account_auth_restored') and outcome='success'),
  (select count(*) from public.profiles where id=${adminA} and account_status='active' and is_active),
  (select count(*) from public.profiles where id=${adminB} and account_status='active' and is_active),
  (select case when coalesce(md5(string_agg(to_jsonb(r)::text,'|' order by r.id)),'')=${sqlLiteralText(baseline.adminAssignmentHash)} then 1 else 0 end
    from public.role_assignments r where r.user_id in (${adminA},${adminB})),
  (select count(*) from auth.users where id=${authority}),
  (select count(*) from public.profiles where id=${authority} and account_kind='technical' and account_status='active' and is_active),
  (select count(*) from public.role_assignments where id=${assignment} and user_id=${authority} and not is_active),
  (select count(*) from public.admin_auth_operations where processing_started_at is not null and status='processing'),
  (select count(*) from pg_trigger t join (values
    ('on_sitaa_auth_user_created','public.handle_sitaa_auth_user_created()'::regprocedure),
    ('on_sitaa_auth_user_email_changed','public.sync_sitaa_profile_email_from_auth()'::regprocedure)
  ) expected(name,function_oid) on expected.name=t.tgname and expected.function_oid=t.tgfoid
    where t.tgrelid='auth.users'::regclass and not t.tgisinternal and t.tgenabled='O'),
  (select count(*) from auth.identities i where i.user_id=${target}
    and md5((select string_agg(to_jsonb(i2)::text,'|' order by i2.id) from auth.identities i2 where i2.user_id=${target}))=${sqlLiteralText(baseline.targetIdentityHash)}),
  (select count(*) from public.profiles p where p.id=${target} and p.activated_at=${sqlLiteralText(baseline.targetActivatedAt)}::timestamptz));
rollback;`;
}

function failureDiagnosticSql(targetId, authorityId) {
  const target = sqlLiteralUuid(targetId);
  const authority = sqlLiteralUuid(authorityId);
  const actions = B3A_ALL_ACTIONS.map(sqlLiteralText).join(",");
  return `
begin;
set transaction read only;
select concat_ws('|','FAILURE_DIAGNOSTIC',
  (select count(*) from public.admin_auth_operations),
  (select count(*) from public.admin_auth_operations where status in ('open','processing','retryable_failure')),
  (select count(*) from public.admin_auth_operations where status<>'succeeded'),
  (select count(*) from public.admin_audit_events where action_code in (${actions})),
  (select count(*) from public.profiles where id=${target} and account_status='active' and is_active),
  (select count(*) from auth.users where id=${target} and (banned_until is null or banned_until<=clock_timestamp())),
  (select count(*) from public.role_assignments where user_id=${authority} and is_active));
rollback;`;
}

function latestCompletedOperationSql(targetId) {
  return `
begin;
set transaction read only;
select concat_ws('|','LATEST_COMPLETED_OPERATION',id,operation_code,status,completed_stage)
from public.admin_auth_operations
where target_profile_id=${sqlLiteralUuid(targetId)} and status='succeeded' and completed_stage='completed'
order by requested_at desc,id desc limit 1;
rollback;`;
}

function verifyPreparedOperationSql(operationId, adminId, targetId, requestId, transition, reason) {
  return `
begin;
set transaction read only;
select concat_ws('|','PREPARED_OPERATION_CONTRACT',
  (select count(*) from public.admin_auth_operations where id=${sqlLiteralUuid(operationId)}
    and request_id=${sqlLiteralUuid(requestId)} and requested_by_profile_id=${sqlLiteralUuid(adminId)}
    and target_profile_id=${sqlLiteralUuid(targetId)} and operation_code=${sqlLiteralText(transition)}
    and reason=${sqlLiteralText(reason)} and status='open' and attempt_count=0),
  (select count(*) from public.admin_auth_operations where request_id=${sqlLiteralUuid(requestId)}),
  (select count(*) from public.admin_auth_operations where target_profile_id=${sqlLiteralUuid(targetId)}
    and status in ('open','processing','retryable_failure')));
rollback;`;
}

function reactivationRecoverySql(operationId, priorOperationId, targetId, adminAId, adminBId, baseline) {
  return `
begin;
set transaction read only;
select concat_ws('|','AUTH_SYNCHRONIZED_RECOVERY_STATE',
  (select count(*) from public.admin_auth_operations where id=${sqlLiteralUuid(operationId)}
    and target_profile_id=${sqlLiteralUuid(targetId)} and operation_code='reactivate'
    and requested_by_profile_id=${sqlLiteralUuid(adminAId)} and completed_by_profile_id=${sqlLiteralUuid(adminBId)}
    and status='succeeded' and completed_stage='completed' and attempt_count=2
    and auth_synchronized_at is not null and auth_audit_event_id is not null
    and profile_audit_event_id is not null and completed_at is not null),
  (select count(*)
   from public.admin_auth_operations current_operation
   join public.admin_auth_operations prior_operation on prior_operation.id=${sqlLiteralUuid(priorOperationId)}
   where current_operation.id=${sqlLiteralUuid(operationId)}
     and prior_operation.target_profile_id=current_operation.target_profile_id
     and prior_operation.requested_at<current_operation.requested_at
     and prior_operation.updated_at<=current_operation.updated_at
     and not exists(
       select 1 from public.admin_auth_operations later
       where later.target_profile_id=current_operation.target_profile_id
         and (later.requested_at,later.id)>(current_operation.requested_at,current_operation.id)
     )),
  (select count(*) from public.profiles where id=${sqlLiteralUuid(targetId)} and account_status='active' and is_active
    and activated_at=${sqlLiteralText(baseline.targetActivatedAt)}::timestamptz and deactivated_at is null),
  (select count(*) from auth.identities i where i.user_id=${sqlLiteralUuid(targetId)}
    and md5((select string_agg(to_jsonb(i2)::text,'|' order by i2.id) from auth.identities i2 where i2.user_id=${sqlLiteralUuid(targetId)}))=${sqlLiteralText(baseline.targetIdentityHash)}));
rollback;`;
}

function parseMarkerLine(lines, prefix, expectedLength = null) {
  const matches = lines.filter((line) => line.startsWith(`${prefix}|`));
  requireCondition(matches.length === 1, "worker_result_marker_invalid");
  const parts = matches[0].split("|");
  if (expectedLength !== null) requireCondition(parts.length === expectedLength, "worker_result_shape_invalid");
  return parts;
}

function sameSnapshot(before, after) {
  return Array.isArray(before) && Array.isArray(after) && before.join("|") === after.join("|");
}

async function setSyntheticAuthority(connection, authorityId, assignmentId, enabled) {
  const parts = executeTransactionalSql(
    connection,
    setSyntheticAuthoritySql(authorityId, assignmentId, enabled),
    "SYNTHETIC_AUTHORITY_STATE",
  );
  requireCondition(parts.length === 2 && parts[1] === (enabled ? "enabled" : "disabled"), "synthetic_authority_toggle_rejected");
  runtimeState.syntheticAuthorityEnabled = enabled;
}

async function coordinateAuthorityLoss(connection, options) {
  const holder = startPsqlWorker(connection, { name: options.holderName, runDirectory: options.runDirectory });
  let waiter = null;
  let observationApproved = false;
  try {
    holder.write(advisoryHolderSql());
    const holderReady = await holder.waitFor("HOLDER_READY|");
    writeBarrier(options.runDirectory, `${options.holderName}-ready`, holderReady.split("|").at(-1));
    waiter = startPsqlWorker(connection, { name: options.waiterName, runDirectory: options.runDirectory });
    waiter.end(options.waiterSql);
    const waiterStarted = await waiter.waitFor("WAITER_STARTED|");
    writeBarrier(options.runDirectory, `${options.waiterName}-started`, waiterStarted.split("|").at(-1));
    observationApproved = await observeAdvisoryLockWait(
      connection,
      holder.applicationName,
      waiter.applicationName,
    );
    requireCondition(observationApproved, "authority_advisory_wait_not_observed");
    runtimeState.advisoryObservations += 1;
    await setSyntheticAuthority(connection, options.authorityId, options.assignmentId, false);
    holder.end(`select 'HOLDER_RELEASED|'||clock_timestamp()::text;\ncommit;`);
    const [holderResult, waiterResult] = await Promise.all([holder.completion, waiter.completion]);
    const holderLines = parsePsqlLines(holderResult);
    const waiterLines = parsePsqlLines(waiterResult);
    const released = parseMarkerLine(holderLines, "HOLDER_RELEASED", 2);
    const started = waiterStarted.split("|");
    requireCondition(Date.parse(started.at(-1)) < Date.parse(released.at(-1)), "authority_waiter_not_started_before_release");
    const outcome = parseMarkerLine(waiterLines, options.resultPrefix, 3);
    requireCondition(outcome[1] === "approved", "authority_loss_outcome_rejected");
    return Object.freeze({
      waiterStartedAt: started.at(-1),
      holderReleasedAt: released.at(-1),
      observationApproved,
    });
  } finally {
    if (!observationApproved) {
      holder.stop();
      waiter?.stop();
    }
    holder.stop();
    waiter?.stop();
    if (runtimeState.syntheticAuthorityEnabled) {
      await setSyntheticAuthority(connection, options.authorityId, options.assignmentId, false);
    }
  }
}

async function waitForLeaseExpiration(connection) {
  const result = spawnPsqlSync(connection, leaseWaitSql(), {
    timeoutMs: LEASE_WAIT_PROCESS_TIMEOUT_MS,
    statementTimeoutMs: 340_000,
  });
  const lines = parsePsqlLines(result);
  const started = parseMarkerLine(lines, "LEASE_WAIT_STARTED", 2);
  const finished = parseMarkerLine(lines, "LEASE_WAIT_FINISHED", 2);
  const elapsed = Date.parse(finished[1]) - Date.parse(started[1]);
  requireCondition(elapsed >= 300_000, "lease_wait_too_short");
  return Object.freeze({ startedAt: started[1], finishedAt: finished[1], elapsed });
}

async function expectPostgrestDenied(factory, failureCode) {
  const result = await authRequest(factory, failureCode);
  requireCondition(Boolean(result?.error), failureCode);
  return true;
}

async function expectPostgrestAllowed(factory, failureCode) {
  const result = await authRequest(factory, failureCode);
  requireCondition(!result?.error, failureCode);
  return result;
}

async function verifyServiceRolePostgrestBoundary(serviceClient) {
  const fakeOperation = {
    id: crypto.randomUUID(),
    request_id: crypto.randomUUID(),
    requested_by_profile_id: crypto.randomUUID(),
    target_profile_id: crypto.randomUUID(),
    operation_code: "deactivate",
    reason: "Intento directo service role",
  };
  await expectPostgrestDenied(() => serviceClient.from("admin_auth_operations").select("id").limit(1), "service_ledger_select_not_denied");
  await expectPostgrestDenied(() => serviceClient.from("admin_auth_operations").insert(fakeOperation), "service_ledger_insert_not_denied");
  await expectPostgrestDenied(() => serviceClient.from("admin_auth_operations").update({ reason: "Cambio directo no permitido" }).eq("id", fakeOperation.id), "service_ledger_update_not_denied");
  await expectPostgrestDenied(() => serviceClient.from("admin_auth_operations").delete().eq("id", fakeOperation.id), "service_ledger_delete_not_denied");
  const auditHead = await expectPostgrestAllowed(
    () => serviceClient.from("admin_audit_events").select("id", { head: true }).limit(0),
    "service_audit_select_not_allowed",
  );
  requireCondition(auditHead.data === null, "service_audit_head_response_rejected");
  await expectPostgrestDenied(
    () => serviceClient.rpc("guard_admin_auth_operation_b3a"),
    "service_guard_not_denied",
  );
  await expectPostgrestDenied(() => serviceClient.rpc("prepare_admin_account_auth_lifecycle_b3a", {
    requested_profile_id: fakeOperation.target_profile_id,
    requested_transition: "deactivate",
    transition_reason: fakeOperation.reason,
    request_id: fakeOperation.request_id,
  }), "service_prepare_not_denied");
  await expectPostgrestDenied(() => serviceClient.rpc("finalize_admin_account_auth_reactivation_b3a", {
    requested_operation_id: fakeOperation.id,
  }), "service_finalize_not_denied");
  await expectPostgrestDenied(() => serviceClient.rpc("get_admin_account_auth_lifecycle_context_b3a", {
    requested_profile_id: fakeOperation.target_profile_id,
  }), "service_context_not_denied");
  await expectPostgrestDenied(() => serviceClient.rpc("transition_admin_account_lifecycle_b2b", {
    requested_profile_id: fakeOperation.target_profile_id,
    requested_transition: "deactivate",
    transition_reason: fakeOperation.reason,
  }), "service_b2b_mutator_not_denied");
}

function removeRunDirectory(runDirectory) {
  if (!runDirectory || !fs.existsSync(runDirectory)) return;
  const root = path.resolve(process.env.SITAA_B3A_REPO_ROOT ?? "");
  const resolved = path.resolve(runDirectory);
  requireCondition(resolved.startsWith(`${root}${path.sep}.sitaa-b3a-concurrency-runtime-`), "runtime_cleanup_path_rejected");
  fs.rmSync(resolved, { recursive: true, force: true });
}

function simulatedConcurrencyOutcome({ holderReadyAt, waiterStartedAt, holderReleasedAt, holderOperationId, waiterOperationId, waiterError }) {
  requireCondition([holderReadyAt, waiterStartedAt, holderReleasedAt].every((value) => Number.isFinite(Date.parse(value))), "simulated_worker_timestamp_rejected");
  requireCondition(Date.parse(waiterStartedAt) < Date.parse(holderReleasedAt), "simulated_waiter_order_rejected");
  if (waiterError) return Object.freeze({ waited: true, error: waiterError });
  requireCondition(UUID_PATTERN.test(holderOperationId) && holderOperationId === waiterOperationId, "simulated_operation_identity_rejected");
  return Object.freeze({ waited: true, sameOperation: true });
}

function simulatedLeaseClaim({ attemptCount, processingStartedAt, now, stage = "profile_suspended" }) {
  const fresh = stage !== "auth_synchronized" && Date.parse(processingStartedAt) > Date.parse(now) - 300_000;
  return Object.freeze({ claimed: !fresh, attemptCount: fresh ? attemptCount : attemptCount + 1 });
}

function simulatedAttemptFence(currentAttempt, submittedAttempt) {
  return submittedAttempt === currentAttempt ? "accepted" : "sitaa_auth_operation_stale_attempt";
}

function simulatedAuthorityResult(authorityBeforeWait, authorityAfterWait) {
  return authorityBeforeWait && !authorityAfterWait ? "42501/sitaa_admin_access_denied" : "unexpected";
}

function simulatedAuthSynchronizedRecovery({ authCalls, stage, recoveringActorDistinct }) {
  return authCalls === 1 && stage === "auth_synchronized" && recoveringActorDistinct
    ? Object.freeze({ finalized: true, authRepeated: false })
    : Object.freeze({ finalized: false, authRepeated: true });
}

function assertMainIrreversibleOrder(source) {
  const normalized = normalizeEol(source);
  const positions = Object.freeze({
    authInventory: normalized.indexOf("await listAllAuthUsers(serviceClient)"),
    listedInventoryValidation: normalized.indexOf("validateListedAuthUserIds(listedAuthUsers)"),
    authDetailFetch: normalized.indexOf("await loadDetailedAuthUsers(serviceClient, listedAuthUserIds)"),
    authDetailValidation: normalized.indexOf("validateDetailedAuthInventory(listedAuthUserIds, detailedAuthUsers)"),
    fixtureAdminValidation: normalized.indexOf("requireDetailedFixtureAdmins(detailedAuthUsers, adminA.id, adminB.id)"),
    targetSelection: normalized.indexOf("selectDetailedTargetC(detailedAuthUsers)"),
    targetLogin: normalized.indexOf("await signInExact(targetClient"),
    adminARefresh: normalized.indexOf("await refreshExact(adminAClient"),
    adminBRefresh: normalized.indexOf("await refreshExact(adminBClient"),
    firstConfirmation: normalized.indexOf('"CONTINUE_B3A_CONCURRENCY_BOUNDARIES"'),
    case17Transactional: normalized.indexOf("case17OrdinaryUsersSql()"),
    case18Transactional: normalized.indexOf("case18ServiceRoleSql(adminA.id, targetId)"),
    secondConfirmation: normalized.indexOf('"CONTINUE_B3A_CONCURRENCY_BOUNDARIES_IRREVERSIBLE"'),
    irreversible: normalized.indexOf("runtimeState.irreversible = true"),
    ordinaryStart: normalized.indexOf("const ordinaryStart = await edgeResponse("),
    ordinaryRetry: normalized.indexOf("const ordinaryRetry = await edgeResponse("),
    serviceRolePostgrest: normalized.indexOf("await verifyServiceRolePostgrestBoundary(serviceClient)"),
    authority: normalized.indexOf("createSyntheticAuthoritySql(authorityId, authorityEmail, adminA.id)"),
    evidencePublication: normalized.indexOf("publishEvidencePair(evidencePath, postcheckPath"),
  });
  requireCondition(
    Object.values(positions).every((position) => Number.isInteger(position) && position >= 0),
    "main_boundary_marker_missing",
  );
  const authenticationPreparation = [
    positions.authInventory,
    positions.listedInventoryValidation,
    positions.authDetailFetch,
    positions.authDetailValidation,
    positions.fixtureAdminValidation,
    positions.targetSelection,
    positions.targetLogin,
    positions.adminARefresh,
    positions.adminBRefresh,
    positions.firstConfirmation,
  ];
  requireCondition(
    authenticationPreparation.every((position, index) => index === 0 || position > authenticationPreparation[index - 1])
      && !normalized.slice(positions.authInventory, positions.authDetailFetch).includes(".identities"),
    "main_auth_inventory_order_fixture_rejected",
  );
  const ordered = [
    positions.firstConfirmation,
    positions.case17Transactional,
    positions.case18Transactional,
    positions.secondConfirmation,
    positions.irreversible,
    positions.ordinaryStart,
    positions.ordinaryRetry,
    positions.serviceRolePostgrest,
    positions.authority,
    positions.evidencePublication,
  ];
  requireCondition(
    ordered.every((position, index) => index === 0 || position > ordered[index - 1]),
    "main_boundary_order_fixture_rejected",
  );
  const beforeIrreversible = normalized.slice(0, positions.irreversible);
  requireCondition(
    !beforeIrreversible.includes("await edgeResponse(")
      && !beforeIrreversible.includes("await verifyServiceRolePostgrestBoundary(")
      && !beforeIrreversible.includes("publishEvidencePair")
      && !beforeIrreversible.includes("publishPartialEvidence")
      && !beforeIrreversible.includes("createSyntheticAuthoritySql"),
    "main_irreversible_boundary_fixture_rejected",
  );
  return positions;
}

async function runSelfTests(repoRoot) {
  const fixtureRoot = path.join(path.dirname(process.argv[1]), "self-test-fixtures");
  const fixtureEvidence = path.join(fixtureRoot, "evidence.local.txt");
  const fixturePostcheck = path.join(fixtureRoot, "postcheck.local.txt");
  const operation = "44444444-4444-4444-8444-444444444444";
  const otherOperation = "55555555-5555-4555-8555-555555555555";
  const holderReadyAt = "2026-08-04T12:00:00.000Z";
  const waiterStartedAt = "2026-08-04T12:00:01.000Z";
  const holderReleasedAt = "2026-08-04T12:00:02.000Z";
  requireCondition(process.version === EXPECTED_NODE_VERSION, "node_version_rejected");
  requireCondition(readSupabaseJsVersion(repoRoot) === EXPECTED_SUPABASE_JS_VERSION, "self_test_dependency_rejected");
  validatePackageHashes(repoRoot);
  requireCondition(
    HARNESS_VERSION === "2026-08-05-hosted-auth-concurrency-boundaries-v7"
      && TARGET_BOOTSTRAP_VERSION === "2026-08-04-b3a-failure-target-bootstrap-v7"
      && REQUIRED_EVIDENCE.length === 6
      && EXPECTED_DELTA.operations === 2
      && EXPECTED_DELTA.administrativeEvents === 4
      && EXPECTED_DELTA.authSuccessEvents === 2
      && EXPECTED_DELTA.profiles === 1
      && EXPECTED_DELTA.roleAssignments === 1,
    "version_or_delta_fixture_rejected",
  );

  const expectedBaselineValues = BASELINE_AGGREGATE_FIELDS.map((field) => String(EXPECTED_BASELINE_AGGREGATES[field]));
  const staleBaselineAggregates = Object.freeze({ ...EXPECTED_BASELINE_AGGREGATES, authSuccessEvents: 2 });
  const staleBaselineValues = BASELINE_AGGREGATE_FIELDS.map((field) => String(staleBaselineAggregates[field]));
  const baselineDifferences = BASELINE_AGGREGATE_FIELDS.filter(
    (field) => staleBaselineAggregates[field] !== EXPECTED_BASELINE_AGGREGATES[field],
  );
  const aggregateTail = ["a".repeat(32), "2026-08-05T00:00:00.000Z", "b".repeat(32)];
  const capturedBaselineDiagnostics = [];
  const previousConsoleError = console.error;
  let staleBaselineRejected = false;
  try {
    console.error = (value) => { capturedBaselineDiagnostics.push(String(value)); };
    parseBaseline(["CONCURRENCY_BOUNDARIES_BASELINE", ...staleBaselineValues, ...aggregateTail]);
  } catch (error) {
    staleBaselineRejected = error instanceof SafeFailure && error.code === "baseline_counts_rejected";
  } finally {
    console.error = previousConsoleError;
  }
  const correctedBaseline = parseBaseline([
    "CONCURRENCY_BOUNDARIES_BASELINE",
    ...expectedBaselineValues,
    ...aggregateTail,
  ]);
  const expectedBaselineChain = numericAggregateChain(
    EXPECTED_BASELINE_AGGREGATES,
    BASELINE_AGGREGATE_FIELDS,
    "baseline_aggregate_fixture_rejected",
  );
  requireCondition(
    staleBaselineRejected
      && capturedBaselineDiagnostics.length === 1
      && capturedBaselineDiagnostics[0] === formatBaselineCountsDiagnostic(staleBaselineAggregates)
      && assertSafeEvidenceLine(capturedBaselineDiagnostics[0]) === capturedBaselineDiagnostics[0]
      && baselineDifferences.join("|") === "authSuccessEvents"
      && expectedBaselineChain === "3|3|3|2|2|1|1|1|1|0|4|4|0|0|8|0|4|6|6|2|2|1|0|1|1"
      && correctedBaseline.aggregates.authSuccessEvents === "4"
      && correctedBaseline.aggregates.operations === "4"
      && correctedBaseline.aggregates.administrativeEvents === "8",
    "baseline_aggregate_fixture_rejected",
  );

  const failureRecoveryTargetScopedAuthSuccessEvents = 2;
  const expectedFinalValues = FINAL_POSTCHECK_AGGREGATE_FIELDS.map(
    (field) => String(EXPECTED_FINAL_POSTCHECK_AGGREGATES[field]),
  );
  const staleFinalAggregates = Object.freeze({ ...EXPECTED_FINAL_POSTCHECK_AGGREGATES, authSuccessEvents: 4 });
  const staleFinalValues = FINAL_POSTCHECK_AGGREGATE_FIELDS.map((field) => String(staleFinalAggregates[field]));
  let staleFinalRejected = false;
  try {
    parseFinalPostcheck(["CONCURRENCY_BOUNDARIES_POSTCHECK", ...staleFinalValues]);
  } catch (error) {
    staleFinalRejected = error instanceof SafeFailure && error.code === "final_postcheck_rejected";
  }
  const correctedFinal = parseFinalPostcheck(["CONCURRENCY_BOUNDARIES_POSTCHECK", ...expectedFinalValues]);
  const expectedFinalChain = numericAggregateChain(
    EXPECTED_FINAL_POSTCHECK_AGGREGATES,
    FINAL_POSTCHECK_AGGREGATE_FIELDS,
    "final_postcheck_aggregate_fixture_rejected",
  );
  requireCondition(
    EXPECTED_DELTA.authSuccessEvents === 2
      && failureRecoveryTargetScopedAuthSuccessEvents === EXPECTED_DELTA.authSuccessEvents
      && Number(correctedBaseline.aggregates.authSuccessEvents) !== failureRecoveryTargetScopedAuthSuccessEvents
      && Number(correctedBaseline.aggregates.authSuccessEvents) + EXPECTED_DELTA.authSuccessEvents === 6
      && staleFinalRejected
      && expectedFinalChain === "4|3|4|3|2|1|1|0|6|6|0|0|12|0|6|1|1|1|1|1|1|0|2|1|1"
      && correctedFinal.authSuccessEvents === "6"
      && correctedFinal.operations === "6"
      && correctedFinal.administrativeEvents === "12",
    "cumulative_auth_success_fixture_rejected",
  );

  for (const unsafeValue of [
    "44444444-4444-4444-8444-444444444444",
    "fixture@example.invalid",
    "a".repeat(64),
    "2026-08-05T00:00:00.000Z",
    "https://fixture.invalid",
    "sb_secret_fixture_service",
  ]) {
    let unsafeDiagnosticRejected = false;
    try {
      formatBaselineCountsDiagnostic(Object.freeze({
        ...EXPECTED_BASELINE_AGGREGATES,
        authSuccessEvents: unsafeValue,
      }));
    } catch (error) {
      unsafeDiagnosticRejected = error instanceof SafeFailure
        && error.code === "baseline_counts_diagnostic_rejected";
    }
    requireCondition(unsafeDiagnosticRejected, "baseline_diagnostic_sanitization_fixture_rejected");
  }

  const expectSafeFailure = async (callback, expectedCode) => {
    try {
      await callback();
      return false;
    } catch (error) {
      return error instanceof SafeFailure && error.code === expectedCode;
    }
  };
  const detailAdminAId = "11111111-1111-4111-8111-111111111111";
  const detailAdminBId = "22222222-2222-4222-8222-222222222222";
  const detailTargetId = "33333333-3333-4333-8333-333333333333";
  const detailReplacementId = "66666666-6666-4666-8666-666666666666";
  const detailSecondTargetId = "77777777-7777-4777-8777-777777777777";
  const targetFixtureEmail = "b3a-failure-target-20260805000000000-abcdef123456@example.invalid";
  const secondTargetFixtureEmail = "b3a-failure-target-20260805000000001-abcdef123457@example.invalid";
  const makeDetailedAuthUser = (id, email, overrides = {}) => Object.freeze({
    id,
    email,
    is_anonymous: false,
    email_confirmed_at: "2026-08-05T00:00:00.000Z",
    banned_until: null,
    app_metadata: {},
    identities: [Object.freeze({
      provider: "email",
      user_id: id,
      identity_data: Object.freeze({ sub: id, email }),
    })],
    ...overrides,
  });
  const detailAdminA = makeDetailedAuthUser(detailAdminAId, "admin-a@example.invalid");
  const detailAdminB = makeDetailedAuthUser(detailAdminBId, "admin-b@example.invalid");
  const detailTarget = makeDetailedAuthUser(detailTargetId, targetFixtureEmail, {
    app_metadata: Object.freeze({
      sitaa_account_kind: "technical",
      sitaa_first_names: TARGET_FIRST_NAMES,
    }),
  });
  const validDetailedUsers = Object.freeze([detailAdminA, detailAdminB, detailTarget]);
  const validListedIds = Object.freeze([detailAdminAId, detailAdminBId, detailTargetId]);
  const detailedById = new Map(validDetailedUsers.map((user) => [user.id, user]));
  const detailCalls = [];
  let activeDetailCalls = 0;
  let maximumActiveDetailCalls = 0;
  const detailFixtureClient = Object.freeze({
    auth: Object.freeze({
      admin: Object.freeze({
        getUserById: async (requestedId) => {
          detailCalls.push(requestedId);
          activeDetailCalls += 1;
          maximumActiveDetailCalls = Math.max(maximumActiveDetailCalls, activeDetailCalls);
          await Promise.resolve();
          activeDetailCalls -= 1;
          return Object.freeze({ data: Object.freeze({ user: detailedById.get(requestedId) ?? null }), error: null });
        },
      }),
    }),
  });
  const loadedDetailedUsers = await loadDetailedAuthUsers(detailFixtureClient, validListedIds);
  const validDetailCounts = validateDetailedAuthInventory(validListedIds, loadedDetailedUsers);
  const validDetailDiagnostic = formatAuthDetailDiagnostic(validDetailCounts);
  const caseInsensitiveIdentityUser = makeDetailedAuthUser(detailAdminAId, detailAdminA.email, {
    identities: [Object.freeze({
      ...detailAdminA.identities[0],
      identity_data: Object.freeze({
        ...detailAdminA.identities[0].identity_data,
        email: detailAdminA.email.toUpperCase(),
      }),
    })],
  });
  requireCondition(
    detailCalls.join("|") === validListedIds.join("|")
      && maximumActiveDetailCalls === 1
      && validDetailDiagnostic === "AUTH_ADMIN_DETAIL_COUNTS|users=3|identity_arrays=3|identities=3|email_identities=3"
      && requireDetailedFixtureAdmins(loadedDetailedUsers, detailAdminAId, detailAdminBId)
      && selectDetailedTargetC(loadedDetailedUsers).id === detailTargetId
      && validateDetailedEmailIdentity(detailAdminA)
      && validateDetailedEmailIdentity(caseInsensitiveIdentityUser)
      && normalizeEol(getDetailedAuthUser.toString()).includes("serviceClient.auth.admin.getUserById(expectedUserId)")
      && normalizeEol(getDetailedAuthUser.toString()).includes("await authRequest(")
      && normalizeEol(loadDetailedAuthUsers.toString()).includes("for (const expectedUserId of expectedUserIds)")
      && normalizeEol(loadDetailedAuthUsers.toString()).includes("await getDetailedAuthUser(")
      && !normalizeEol(loadDetailedAuthUsers.toString()).includes("Promise.all"),
    "auth_user_detail_positive_fixture_rejected",
  );

  const superficialIdentityVariants = [
    [undefined, undefined, undefined],
    [null, null, null],
    [[], [], []],
    [undefined, null, []],
    [[Object.freeze({ provider: "stale" })], [], undefined],
  ];
  for (const identityVariant of superficialIdentityVariants) {
    const superficialUsers = validDetailedUsers.map((user, index) => Object.freeze({
      id: user.id,
      identities: identityVariant[index],
    }));
    const listedIds = validateListedAuthUserIds(superficialUsers);
    const counts = validateDetailedAuthInventory(listedIds, validDetailedUsers);
    requireCondition(
      listedIds.join("|") === validListedIds.join("|")
        && counts.identities === 3
        && counts.emailIdentities === 3,
      "auth_user_superficial_inventory_fixture_rejected",
    );
  }

  requireCondition(
    await expectSafeFailure(
      () => validateListedAuthUserIds(validDetailedUsers.slice(0, 2)),
      "auth_user_inventory_count_rejected",
    )
      && await expectSafeFailure(
        () => validateListedAuthUserIds([...validDetailedUsers, makeDetailedAuthUser(detailReplacementId, "replacement@example.invalid")]),
        "auth_user_inventory_count_rejected",
      )
      && await expectSafeFailure(
        () => validateListedAuthUserIds([{ id: detailAdminAId }, { id: detailAdminAId }, { id: detailTargetId }]),
        "auth_user_inventory_duplicate_rejected",
      ),
    "auth_user_inventory_negative_fixture_rejected",
  );

  const detailErrorClient = Object.freeze({
    auth: Object.freeze({ admin: Object.freeze({
      getUserById: async () => Object.freeze({ data: Object.freeze({ user: null }), error: Object.freeze({ name: "FixtureAuthError" }) }),
    }) }),
  });
  const detailNullClient = Object.freeze({
    auth: Object.freeze({ admin: Object.freeze({
      getUserById: async () => Object.freeze({ data: Object.freeze({ user: null }), error: null }),
    }) }),
  });
  const detailMismatchClient = Object.freeze({
    auth: Object.freeze({ admin: Object.freeze({
      getUserById: async () => Object.freeze({ data: Object.freeze({ user: detailAdminB }), error: null }),
    }) }),
  });
  requireCondition(
    await expectSafeFailure(
      () => getDetailedAuthUser(detailErrorClient, detailAdminAId, "auth_user_detail_fetch_failed"),
      "auth_user_detail_fetch_failed",
    )
      && await expectSafeFailure(
        () => getDetailedAuthUser(detailNullClient, detailAdminAId, "auth_user_detail_fetch_failed"),
        "auth_user_detail_response_rejected",
      )
      && await expectSafeFailure(
        () => getDetailedAuthUser(detailMismatchClient, detailAdminAId, "auth_user_detail_fetch_failed"),
        "auth_user_detail_response_rejected",
      )
      && await expectSafeFailure(
        () => validateDetailedAuthInventory(validListedIds, [
          detailAdminA,
          detailAdminB,
          makeDetailedAuthUser(detailReplacementId, "replacement@example.invalid"),
        ]),
        "auth_user_detail_set_rejected",
      ),
    "auth_user_detail_response_negative_fixture_rejected",
  );

  const canonicalIdentity = detailAdminA.identities[0];
  const identityContractNegatives = [
    makeDetailedAuthUser(detailAdminAId, detailAdminA.email, { identities: undefined }),
    makeDetailedAuthUser(detailAdminAId, detailAdminA.email, { identities: null }),
    makeDetailedAuthUser(detailAdminAId, detailAdminA.email, { identities: [] }),
    makeDetailedAuthUser(detailAdminAId, detailAdminA.email, { identities: [canonicalIdentity, canonicalIdentity] }),
    makeDetailedAuthUser(detailAdminAId, detailAdminA.email, { identities: [{ ...canonicalIdentity, user_id: detailAdminBId }] }),
    makeDetailedAuthUser(detailAdminAId, detailAdminA.email, { identities: [{ ...canonicalIdentity, identity_data: undefined }] }),
    makeDetailedAuthUser(detailAdminAId, detailAdminA.email, {
      identities: [{ ...canonicalIdentity, identity_data: { ...canonicalIdentity.identity_data, sub: detailAdminBId } }],
    }),
  ];
  for (const invalidUser of identityContractNegatives) {
    requireCondition(
      await expectSafeFailure(
        () => validateDetailedEmailIdentity(invalidUser),
        "auth_user_detail_identity_contract_rejected",
      ),
      "auth_user_detail_identity_negative_fixture_rejected",
    );
  }
  const anonymousPropertyAbsent = Object.freeze(Object.fromEntries(
    Object.entries(detailAdminA).filter(([key]) => key !== "is_anonymous"),
  ));
  const anonymousContractNegatives = [
    anonymousPropertyAbsent,
    makeDetailedAuthUser(detailAdminAId, detailAdminA.email, { is_anonymous: undefined }),
    makeDetailedAuthUser(detailAdminAId, detailAdminA.email, { is_anonymous: null }),
    makeDetailedAuthUser(detailAdminAId, detailAdminA.email, { is_anonymous: true }),
    makeDetailedAuthUser(detailAdminAId, detailAdminA.email, { is_anonymous: "false" }),
    makeDetailedAuthUser(detailAdminAId, detailAdminA.email, { is_anonymous: 0 }),
    makeDetailedAuthUser(detailAdminAId, detailAdminA.email, { is_anonymous: 1 }),
    makeDetailedAuthUser(detailAdminAId, detailAdminA.email, { is_anonymous: Object.freeze({}) }),
    makeDetailedAuthUser(detailAdminAId, detailAdminA.email, { is_anonymous: Object.freeze([]) }),
  ];
  requireCondition(
    anonymousContractNegatives.length === 9
      && !Object.prototype.hasOwnProperty.call(anonymousPropertyAbsent, "is_anonymous"),
    "auth_user_detail_anonymous_fixture_setup_rejected",
  );
  for (const invalidUser of anonymousContractNegatives) {
    requireCondition(
      await expectSafeFailure(
        () => validateDetailedEmailIdentity(invalidUser),
        "auth_user_detail_identity_contract_rejected",
      ),
      "auth_user_detail_anonymous_negative_fixture_rejected",
    );
  }
  const emailIdentityNegatives = [
    makeDetailedAuthUser(detailAdminAId, detailAdminA.email, {
      identities: [{ ...canonicalIdentity, provider: "google" }],
    }),
    makeDetailedAuthUser(detailAdminAId, detailAdminA.email, {
      identities: [{
        ...canonicalIdentity,
        identity_data: { ...canonicalIdentity.identity_data, email: "different@example.invalid" },
      }],
    }),
  ];
  for (const invalidUser of emailIdentityNegatives) {
    requireCondition(
      await expectSafeFailure(
        () => validateDetailedEmailIdentity(invalidUser),
        "auth_user_detail_email_identity_rejected",
      ),
      "auth_user_detail_email_identity_negative_fixture_rejected",
    );
  }

  const secondDetailedTarget = makeDetailedAuthUser(detailSecondTargetId, secondTargetFixtureEmail);
  requireCondition(
    await expectSafeFailure(
      () => selectDetailedTargetC([detailAdminA, detailAdminB]),
      "target_inventory_rejected",
    )
      && await expectSafeFailure(
        () => selectDetailedTargetC([detailTarget, secondDetailedTarget]),
        "target_inventory_rejected",
      ),
    "target_inventory_negative_fixture_rejected",
  );

  for (const unsafeDiagnostic of [
    `${validDetailDiagnostic}|user=${detailAdminAId}`,
    `${validDetailDiagnostic}|email=fixture@example.invalid`,
    "AUTH_ADMIN_DETAIL_COUNTS|raw={\"identities\":[]}",
  ]) {
    requireCondition(
      await expectSafeFailure(
        () => assertSafeAuthDetailDiagnostic(unsafeDiagnostic),
        "auth_user_detail_diagnostic_rejected",
      ),
      "auth_user_detail_diagnostic_sanitization_fixture_rejected",
    );
  }

  const opaquePublic = "sb_publishable_fixture_public";
  const opaqueSecret = "sb_secret_fixture_service";
  const legacyPublic = "legacyHeader.legacyPayload.legacySignature";
  const userJwt = "userHeader.userPayload.userSignature";
  requireCondition(
    validatePublicApiKey(opaquePublic) === opaquePublic
      && validatePrivilegedApiKey(opaqueSecret) === opaqueSecret
      && validatePublicApiKey(legacyPublic) === legacyPublic,
    "api_key_shape_fixture_rejected",
  );
  const transportFacts = async (apiKey, authorization) => {
    const originalHeaders = new Headers({ apikey: apiKey, Authorization: authorization, "x-fixture": "preserved" });
    const originalInit = { method: "GET", headers: originalHeaders };
    let facts = null;
    const fakeFetch = async (input, receivedInit) => {
      facts = Object.freeze({
        input,
        apikey: receivedInit.headers.get("apikey"),
        authorization: receivedInit.headers.get("authorization"),
        headersCloned: receivedInit.headers !== originalHeaders,
        initCloned: receivedInit !== originalInit,
        signal: receivedInit.signal instanceof AbortSignal,
      });
      return Object.freeze({ ok: true });
    };
    await createApiKeyAwareBoundedFetch(apiKey, fakeFetch)("https://fixture.invalid/transport", originalInit);
    requireCondition(originalHeaders.get("authorization") === authorization && !("signal" in originalInit), "transport_input_mutated");
    return facts;
  };
  const opaqueFacts = await transportFacts(opaquePublic, `Bearer ${opaquePublic}`);
  const secretFacts = await transportFacts(opaqueSecret, `Bearer ${opaqueSecret}`);
  const jwtFacts = await transportFacts(opaquePublic, `Bearer ${userJwt}`);
  requireCondition(
    opaqueFacts.apikey === opaquePublic && opaqueFacts.authorization === null
      && secretFacts.apikey === opaqueSecret && secretFacts.authorization === null
      && jwtFacts.authorization === `Bearer ${userJwt}`
      && [opaqueFacts, secretFacts, jwtFacts].every((facts) => facts.headersCloned && facts.initCloned && facts.signal),
    "api_key_transport_fixture_rejected",
  );
  const parsedConnection = parsePostgresConnectionUri(
    `postgresql://postgres.${EXPECTED_PROJECT_REF}:fixture-password@db.${EXPECTED_PROJECT_REF}.supabase.co:5432/postgres?sslmode=require`,
  );
  const childEnvironment = postgresChildEnvironment(parsedConnection, 30_000, {
    PATH: "fixture-path",
    SITAA_B3A_DB_URL: "must-not-propagate",
    PGPASSWORD: "must-be-replaced",
  }, "sitaa_b3a_fixture_worker");
  requireCondition(
    childEnvironment.PGHOST === `db.${EXPECTED_PROJECT_REF}.supabase.co`
      && childEnvironment.PGPASSWORD === "fixture-password"
      && childEnvironment.PATH === "fixture-path"
      && !("SITAA_B3A_DB_URL" in childEnvironment)
      && childEnvironment.PGOPTIONS.includes("statement_timeout=30000")
      && childEnvironment.PGAPPNAME === "sitaa_b3a_fixture_worker"
      && workerApplicationName("fixture-holder", fixtureRoot) !== workerApplicationName("fixture-waiter", fixtureRoot),
    "postgres_transport_fixture_rejected",
  );
  requireCondition(
    parsePsqlMarker({ status: 0, stdout: "FIXTURE|approved\r\n", stderr: "" }, "FIXTURE").join("|") === "FIXTURE|approved",
    "psql_parser_fixture_rejected",
  );

  const same = simulatedConcurrencyOutcome({ holderReadyAt, waiterStartedAt, holderReleasedAt, holderOperationId: operation, waiterOperationId: operation });
  const conflict = simulatedConcurrencyOutcome({ holderReadyAt, waiterStartedAt, holderReleasedAt, waiterError: "sitaa_auth_operation_request_id_conflict" });
  const busy = simulatedConcurrencyOutcome({ holderReadyAt, waiterStartedAt, holderReleasedAt, waiterError: "sitaa_auth_operation_target_busy" });
  let negativeOrderRejected = false;
  try {
    simulatedConcurrencyOutcome({ holderReadyAt, waiterStartedAt: holderReleasedAt, holderReleasedAt, holderOperationId: operation, waiterOperationId: operation });
  } catch (error) {
    negativeOrderRejected = error instanceof SafeFailure && error.code === "simulated_waiter_order_rejected";
  }
  requireCondition(
    same.sameOperation && same.waited
      && conflict.error === "sitaa_auth_operation_request_id_conflict"
      && busy.error === "sitaa_auth_operation_target_busy"
      && negativeOrderRejected,
    "concurrency_worker_fixture_rejected",
  );
  const approvedObservation = ["ADVISORY_WAIT_OBSERVATION", "1", "1", "1", "1", "1", "1"];
  requireCondition(
    advisoryObservationApproved(approvedObservation)
      && !advisoryObservationApproved(["ADVISORY_WAIT_OBSERVATION", "1", "0", "1", "0", "0", "0"])
      && !advisoryObservationApproved(["ADVISORY_WAIT_OBSERVATION", "1", "1", "1", "0", "0", "1"])
      && !advisoryObservationApproved(["ADVISORY_WAIT_OBSERVATION", "1", "1", "1", "1", "1", "0"])
      && !advisoryObservationApproved(["ADVISORY_WAIT_OBSERVATION", "2", "1", "2", "1", "1", "1"]),
    "advisory_observation_shape_fixture_rejected",
  );
  let duplicateApplicationRejected = false;
  try {
    await observeAdvisoryLockWait(null, "sitaa_b3a_duplicate", "sitaa_b3a_duplicate", {
      probe: async () => approvedObservation,
    });
  } catch (error) {
    duplicateApplicationRejected = error instanceof SafeFailure && error.code === "observer_application_name_duplicated";
  }
  let observerTimedOut = false;
  let simulatedNow = 0;
  try {
    await observeAdvisoryLockWait(null, "sitaa_b3a_holder", "sitaa_b3a_waiter", {
      timeoutMs: 3,
      pollMs: 1,
      now: () => simulatedNow++,
      pause: async () => {},
      probe: async () => ["ADVISORY_WAIT_OBSERVATION", "1", "1", "1", "0", "0", "0"],
    });
  } catch (error) {
    observerTimedOut = error instanceof SafeFailure && error.code === "advisory_observer_timeout";
  }
  const workerPairSource = normalizeEol(coordinateWorkerPair.toString());
  const authorityPairSource = normalizeEol(coordinateAuthorityLoss.toString());
  requireCondition(
    duplicateApplicationRejected
      && observerTimedOut
      && workerPairSource.indexOf("observeAdvisoryLockWait") < workerPairSource.indexOf("holder.end")
      && authorityPairSource.indexOf("observeAdvisoryLockWait") < authorityPairSource.indexOf("setSyntheticAuthority")
      && authorityPairSource.indexOf("observeAdvisoryLockWait") < authorityPairSource.indexOf("holder.end"),
    "advisory_observer_order_fixture_rejected",
  );

  const canonicalHandlerFixture = Object.freeze({
    signature: EXPECTED_AUTH_HANDLER_SIGNATURE,
    owner: "postgres",
    securityDefiner: true,
    volatility: "v",
    searchPath: "pg_catalog, public, auth",
    acl: EXPECTED_AUTH_HANDLER_ACL,
    definitionMd5: EXPECTED_AUTH_HANDLER_MD5,
    triggers: "exact",
  });
  const rejectedHandlerFixtures = [
    { ...canonicalHandlerFixture, definitionMd5: "00000000000000000000000000000000" },
    { ...canonicalHandlerFixture, owner: "service_role" },
    { ...canonicalHandlerFixture, acl: "{postgres=X/postgres}" },
    { ...canonicalHandlerFixture, searchPath: "public" },
    { ...canonicalHandlerFixture, triggers: "extra" },
    { ...canonicalHandlerFixture, signature: "public.handle_sitaa_auth_user_created(text)" },
  ];
  requireCondition(
    authHandlerFixtureApproved(canonicalHandlerFixture)
      && rejectedHandlerFixtures.every((fixture) => !authHandlerFixtureApproved(fixture))
      && authHandlerContractSql("AUTH_HANDLER_FIXTURE").includes(EXPECTED_AUTH_HANDLER_MD5)
      && authHandlerContractSql("AUTH_HANDLER_FIXTURE").includes("not exists(\n      select 1 from pg_trigger"),
    "auth_handler_contract_fixture_rejected",
  );
  parseAuthHandlerContract(
    ["AUTH_HANDLER_FIXTURE", "1", "1", "1", "1", "1", "1", "1", "1"],
    "AUTH_HANDLER_FIXTURE",
  );
  for (const rejectedIndex of [1, 2, 3, 4, 5, 6, 7, 8]) {
    const rejectedParts = ["AUTH_HANDLER_FIXTURE", "1", "1", "1", "1", "1", "1", "1", "1"];
    rejectedParts[rejectedIndex] = "0";
    let rejected = false;
    try {
      parseAuthHandlerContract(rejectedParts, "AUTH_HANDLER_FIXTURE");
    } catch (error) {
      rejected = error instanceof SafeFailure && error.code === "auth_handler_contract_rejected";
    }
    requireCondition(rejected, "auth_handler_parser_negative_fixture_rejected");
  }
  const freshLease = simulatedLeaseClaim({ attemptCount: 1, processingStartedAt: "2026-08-04T12:00:00.000Z", now: "2026-08-04T12:04:59.999Z" });
  const expiredLease = simulatedLeaseClaim({ attemptCount: 1, processingStartedAt: "2026-08-04T12:00:00.000Z", now: "2026-08-04T12:05:00.001Z" });
  requireCondition(
    !freshLease.claimed && freshLease.attemptCount === 1
      && expiredLease.claimed && expiredLease.attemptCount === 2
      && simulatedAttemptFence(2, 1) === "sitaa_auth_operation_stale_attempt"
      && simulatedAttemptFence(2, 2) === "accepted",
    "lease_and_attempt_fixture_rejected",
  );
  requireCondition(
    Date.parse(holderReleasedAt) < Date.parse("2026-08-04T12:00:02.010Z")
      && Date.parse("2026-08-04T12:00:02.010Z") <= Date.parse("2026-08-04T12:00:02.011Z"),
    "post_lock_clock_fixture_rejected",
  );
  const leaseEvidenceHash = "0123456789abcdef0123456789abcdef";
  const leaseBeforeFixture = Object.freeze({
    operationId: operation,
    stage: "profile_suspended",
    attemptCount: 1,
    processingStartedAt: "2026-08-04T12:00:00.000Z",
    updatedAt: "2026-08-04T12:00:00.000Z",
    evidenceHash: leaseEvidenceHash,
  });
  const leaseAfterFixture = Object.freeze({
    operationId: operation,
    stage: "profile_suspended",
    attemptCount: 2,
    processingStartedAt: "2026-08-04T12:05:03.000Z",
    updatedAt: "2026-08-04T12:05:03.001Z",
    evidenceHash: leaseEvidenceHash,
  });
  requireCondition(
    recoveredLeasePostcheckApproved(
      leaseBeforeFixture,
      leaseAfterFixture,
      "2026-08-04T12:05:02.000Z",
      "2026-08-04T12:05:02.500Z",
      "2026-08-04T12:05:01.000Z",
    )
      && !recoveredLeasePostcheckApproved(
        leaseBeforeFixture,
        { ...leaseAfterFixture, processingStartedAt: "2026-08-04T12:05:02.400Z" },
        "2026-08-04T12:05:02.000Z",
        "2026-08-04T12:05:02.500Z",
        "2026-08-04T12:05:01.000Z",
      )
      && !recoveredLeasePostcheckApproved(
        leaseBeforeFixture,
        { ...leaseAfterFixture, evidenceHash: "ffffffffffffffffffffffffffffffff" },
        "2026-08-04T12:05:02.000Z",
        "2026-08-04T12:05:02.500Z",
        "2026-08-04T12:05:01.000Z",
      ),
    "lease_recovery_postcheck_fixture_rejected",
  );
  requireCondition(
    ["claim", "record", "final_replay"].every(() => simulatedAuthorityResult(true, false) === "42501/sitaa_admin_access_denied")
      && simulatedAuthSynchronizedRecovery({ authCalls: 1, stage: "auth_synchronized", recoveringActorDistinct: true }).authRepeated === false,
    "authority_and_recovery_fixture_rejected",
  );
  const case17Identifiers = [];
  for (let index = 0; index < 100; index += 1) {
    const sql = case17OrdinaryUsersSql();
    const identifiers = case17InstitutionalIdentifiersFromSql(sql);
    requireCondition(
      !sql.includes("person_type='worker'")
        && sql.includes("person_type='professor'")
        && sql.includes("institutional_id_type='worker_number'")
        && sql.includes("person_type='student'")
        && sql.includes("institutional_id_type='student_account'")
        && !sql.includes("'9'||substr(replace(gen_random_uuid()")
        && !sql.includes("'8'||substr(replace(gen_random_uuid()")
        && sql.trim().endsWith("rollback;"),
      "case17_profile_fixture_rejected",
    );
    case17Identifiers.push(identifiers.professor, identifiers.student);
  }
  requireCondition(
    case17Identifiers.length === 200
      && case17Identifiers.every((value) => /^[0-9]{1,50}$/.test(value)),
    "case17_identifier_generation_fixture_rejected",
  );
  const canonicalCase17 = case17OrdinaryUsersSql();
  const malformedCase17HashComparisons = [
    canonicalCase17.replace(
      CASE17_LEDGER_HASH_COMPARISON,
      CASE17_LEDGER_HASH_COMPARISON.replace("))=(", ")=("),
    ),
    canonicalCase17.replace(
      CASE17_AUDIT_HASH_COMPARISON,
      CASE17_AUDIT_HASH_COMPARISON.replace("))=(", ")=("),
    ),
  ];
  for (const malformedCase17 of malformedCase17HashComparisons) {
    requireCondition(
      malformedCase17 !== canonicalCase17
        && await expectSafeFailure(
          () => assertCase17HashComparisonContract(malformedCase17),
          "case17_hash_comparison_contract_rejected",
        ),
      "case17_hash_comparison_negative_fixture_rejected",
    );
  }
  let workerRejected = false;
  let lettersRejected = false;
  try {
    assertCase17ProfileContract(canonicalCase17.replace("person_type='professor'", "person_type='worker'"));
  } catch (error) {
    workerRejected = error instanceof SafeFailure && error.code === "case17_worker_person_type_rejected";
  }
  try {
    const identifiers = case17InstitutionalIdentifiersFromSql(canonicalCase17);
    assertCase17ProfileContract(canonicalCase17.replace(`'${identifiers.professor}'`, "'7abc'"));
  } catch (error) {
    lettersRejected = error instanceof SafeFailure
      && (error.code === "case17_identifier_sql_contract_rejected" || error.code === "case17_identifier_value_rejected");
  }
  requireCondition(workerRejected && lettersRejected, "case17_negative_fixture_rejected");

  const case18Sql = case18ServiceRoleSql(operation, otherOperation);
  requireCondition(
    case18Sql.includes("set local role service_role")
      && case18Sql.includes("audit_select")
      && case18Sql.includes("audit_insert")
      && case18Sql.includes("privilege_type in ('SELECT','INSERT')")
      && case18Sql.includes("attacl is not null")
      && case18Sql.includes("transition_admin_account_lifecycle_b2b")
      && case18Sql.trim().endsWith("rollback;")
      && !normalizeEol(verifyServiceRolePostgrestBoundary.toString()).includes("service_audit_select_not_denied")
      && normalizeEol(verifyServiceRolePostgrestBoundary.toString()).includes("head: true"),
    "case18_acl_fixture_rejected",
  );
  let deniedAuditSelectExpectationRejected = false;
  try {
    assertCase18AclContract(
      case18Sql.replace(
        "perform 1 from public.admin_audit_events where false",
        "begin perform 1 from public.admin_audit_events; raise exception 'case18_audit_unexpected'; exception when insufficient_privilege then null; end",
      ),
      normalizeEol(verifyServiceRolePostgrestBoundary.toString())
        .replaceAll("service_audit_select_not_allowed", "service_audit_select_not_denied"),
    );
  } catch (error) {
    deniedAuditSelectExpectationRejected = error instanceof SafeFailure
      && error.code === "case18_audit_acl_contract_rejected";
  }
  requireCondition(deniedAuditSelectExpectationRejected, "case18_negative_acl_fixture_rejected");
  requireCondition(
    leaseWaitSql().includes(`pg_sleep(${LEASE_WAIT_SECONDS})`)
      && !leaseWaitSql().includes("update ")
      && !leaseWaitSql().includes("processing_started_at=")
      && authorityLossClaimSql(operation, otherOperation, "AUTHORITY_LOSS_CLAIM_RESULT").includes("sitaa_admin_access_denied")
      && authorityLossRecordSql(operation, otherOperation, 2).includes("sitaa_admin_access_denied"),
    "lease_authority_sql_fixture_rejected",
  );

  const hung = spawn(process.execPath, ["-e", "setInterval(() => {}, 1000)"], { windowsHide: true, stdio: "ignore" });
  const hungStopped = new Promise((resolve) => hung.once("close", () => resolve(true)));
  setTimeout(() => hung.kill(), 25);
  requireCondition(await Promise.race([hungStopped, new Promise((resolve) => setTimeout(() => resolve(false), 2_000))]), "hung_worker_cleanup_fixture_rejected");
  const timeoutFixture = await Promise.race([
    new Promise((resolve) => setTimeout(() => resolve("timeout"), 20)),
    new Promise((resolve) => setTimeout(() => resolve("late"), 200)),
  ]);
  requireCondition(timeoutFixture === "timeout", "worker_timeout_fixture_rejected");

  requireCondition(
    assertSafeEvidenceLine("CASE_18_SERVICE_ROLE_BOUNDARY|APPROVED").endsWith("APPROVED")
      && assertSafeEvidenceLine("LEASE_RECOVERED_AFTER_5_MINUTES|true").endsWith("true")
      && containsForbiddenEvidence("https://fixture.invalid")
      && containsForbiddenEvidence("fixture@example.invalid")
      && containsForbiddenEvidence(operation),
    "evidence_sanitization_fixture_rejected",
  );
  fs.mkdirSync(fixtureRoot, { recursive: true });
  try {
    const approvedEvidence = [
      `HARNESS_VERSION|${HARNESS_VERSION}`,
      "BASELINE|APPROVED",
      "HOSTED_AUTH_CONCURRENCY_BOUNDARIES|APPROVED",
    ];
    const approvedPostcheck = [
      `HARNESS_VERSION|${HARNESS_VERSION}`,
      "AUTH_HANDLER_STATE|CANONICAL",
      "READ_ONLY_TRANSACTION|true",
      "ROLLBACK|true",
      "HOSTED_AUTH_CONCURRENCY_BOUNDARIES_POSTCHECK|APPROVED",
    ];
    publishEvidencePair(fixtureEvidence, fixturePostcheck, approvedEvidence, approvedPostcheck);
    requireCondition(fs.existsSync(fixtureEvidence) && fs.existsSync(fixturePostcheck), "atomic_evidence_success_fixture_rejected");
    const completedEvidenceHash = sha256Buffer(fs.readFileSync(fixtureEvidence));
    const completedPostcheckHash = sha256Buffer(fs.readFileSync(fixturePostcheck));
    let completedPairRejected = false;
    let completedPairUnlinks = 0;
    try {
      reconcileEvidencePublication(fixtureEvidence, fixturePostcheck, {
        recoverOrphanPostcheck: false,
        unlinkFile: () => { completedPairUnlinks += 1; },
      });
    } catch (error) {
      completedPairRejected = error instanceof SafeFailure && error.code === "concurrency_evidence_already_exists";
    }
    requireCondition(
      completedPairRejected
        && completedPairUnlinks === 0
        && sha256Buffer(fs.readFileSync(fixtureEvidence)) === completedEvidenceHash
        && sha256Buffer(fs.readFileSync(fixturePostcheck)) === completedPostcheckHash,
      "completed_evidence_pair_fixture_rejected",
    );
    fs.unlinkSync(fixtureEvidence);
    fs.unlinkSync(fixturePostcheck);

    let interruptedBeforePostcheck = false;
    try {
      publishEvidencePair(
        fixtureEvidence,
        fixturePostcheck,
        approvedEvidence,
        approvedPostcheck,
        { interruptAt: "before_postcheck" },
      );
    } catch (error) {
      interruptedBeforePostcheck = error instanceof SafeFailure
        && error.code === "evidence_pair_interrupted_before_postcheck";
    }
    requireCondition(
      interruptedBeforePostcheck && !fs.existsSync(fixtureEvidence) && !fs.existsSync(fixturePostcheck),
      "evidence_interruption_before_postcheck_fixture_rejected",
    );

    let interruptedAfterPostcheck = false;
    try {
      publishEvidencePair(
        fixtureEvidence,
        fixturePostcheck,
        approvedEvidence,
        approvedPostcheck,
        { interruptAt: "after_postcheck" },
      );
    } catch (error) {
      interruptedAfterPostcheck = error instanceof SafeFailure
        && error.code === "evidence_pair_interrupted_after_postcheck";
    }
    requireCondition(
      interruptedAfterPostcheck
        && !fs.existsSync(fixtureEvidence)
        && fs.existsSync(fixturePostcheck),
      "evidence_interruption_after_postcheck_fixture_rejected",
    );
    const orphanPostcheckHash = sha256Buffer(fs.readFileSync(fixturePostcheck));
    let readOnlyOrphanRejected = false;
    let readOnlyOrphanUnlinks = 0;
    try {
      reconcileEvidencePublication(fixtureEvidence, fixturePostcheck, {
        recoverOrphanPostcheck: false,
        unlinkFile: () => { readOnlyOrphanUnlinks += 1; },
      });
    } catch (error) {
      readOnlyOrphanRejected = error instanceof SafeFailure
        && error.code === "orphan_postcheck_recovery_not_allowed";
    }
    requireCondition(
      readOnlyOrphanRejected
        && readOnlyOrphanUnlinks === 0
        && fs.existsSync(fixturePostcheck)
        && sha256Buffer(fs.readFileSync(fixturePostcheck)) === orphanPostcheckHash,
      "read_only_orphan_postcheck_fixture_rejected",
    );
    let normalOrphanUnlinks = 0;
    reconcileEvidencePublication(fixtureEvidence, fixturePostcheck, {
      recoverOrphanPostcheck: true,
      unlinkFile: (filePath) => {
        normalOrphanUnlinks += 1;
        fs.unlinkSync(filePath);
      },
    });
    requireCondition(
      normalOrphanUnlinks === 1 && !fs.existsSync(fixtureEvidence) && !fs.existsSync(fixturePostcheck),
      "orphan_postcheck_recovery_fixture_rejected",
    );

    writeExclusiveDurable(fixturePostcheck, [
      `HARNESS_VERSION|${HARNESS_VERSION}`,
      "POSTCHECK_STATE|UNKNOWN",
    ]);
    const unknownPostcheckHash = sha256Buffer(fs.readFileSync(fixturePostcheck));
    let unknownPostcheckUnlinks = 0;
    for (const recoverOrphanPostcheck of [false, true]) {
      let unknownPostcheckRejected = false;
      try {
        reconcileEvidencePublication(fixtureEvidence, fixturePostcheck, {
          recoverOrphanPostcheck,
          unlinkFile: () => { unknownPostcheckUnlinks += 1; },
        });
      } catch (error) {
        unknownPostcheckRejected = error instanceof SafeFailure
          && error.code === "unrecognized_orphan_postcheck";
      }
      requireCondition(
        unknownPostcheckRejected
          && fs.existsSync(fixturePostcheck)
          && sha256Buffer(fs.readFileSync(fixturePostcheck)) === unknownPostcheckHash,
        "unknown_orphan_postcheck_fixture_rejected",
      );
    }
    requireCondition(unknownPostcheckUnlinks === 0, "unknown_orphan_postcheck_unlink_fixture_rejected");
    fs.unlinkSync(fixturePostcheck);

    writeExclusiveDurable(fixtureEvidence, approvedEvidence);
    const principalWithoutPostcheckHash = sha256Buffer(fs.readFileSync(fixtureEvidence));
    let principalWithoutPostcheckRejected = false;
    let principalWithoutPostcheckUnlinks = 0;
    try {
      reconcileEvidencePublication(fixtureEvidence, fixturePostcheck, {
        recoverOrphanPostcheck: false,
        unlinkFile: () => { principalWithoutPostcheckUnlinks += 1; },
      });
    } catch (error) {
      principalWithoutPostcheckRejected = error instanceof SafeFailure
        && error.code === "committed_evidence_without_postcheck";
    }
    requireCondition(
      principalWithoutPostcheckRejected
        && principalWithoutPostcheckUnlinks === 0
        && fs.existsSync(fixtureEvidence)
        && !fs.existsSync(fixturePostcheck)
        && sha256Buffer(fs.readFileSync(fixtureEvidence)) === principalWithoutPostcheckHash,
      "principal_without_postcheck_fixture_rejected",
    );
    fs.unlinkSync(fixtureEvidence);

    publishPartialEvidence(fixtureEvidence, [
      `HARNESS_VERSION|${HARNESS_VERSION}`,
      "FAILURE_PHASE|fixture",
      "AUTH_HANDLER_BASELINE|APPROVED",
      "CASE_17_ORDINARY_USERS|APPROVED",
      "FAILURE_DIAGNOSTIC|RECORDED",
      "DIAGNOSTIC_READ_ONLY_TRANSACTION|true",
      "DIAGNOSTIC_ROLLBACK|true",
      "HOSTED_AUTH_CONCURRENCY_BOUNDARIES|REJECTED|fixture_failure",
    ]);
    const partialLines = normalizeEol(fs.readFileSync(fixtureEvidence, "utf8")).split("\n").filter(Boolean);
    requireCondition(
      fs.existsSync(fixtureEvidence)
        && !fs.existsSync(fixturePostcheck)
        && partialLines.includes("AUTH_HANDLER_BASELINE|APPROVED")
        && partialLines.includes("FAILURE_DIAGNOSTIC|RECORDED")
        && partialLines.filter((line) => line.startsWith("HOSTED_AUTH_CONCURRENCY_BOUNDARIES|")).length === 1
        && !evidenceHasContradiction(partialLines),
      "partial_evidence_fixture_rejected",
    );
    let partialPublicationFailureSurfaced = false;
    try {
      publishPartialEvidence(fixtureEvidence, [
        `HARNESS_VERSION|${HARNESS_VERSION}`,
        "HOSTED_AUTH_CONCURRENCY_BOUNDARIES|REJECTED|second_failure",
      ]);
    } catch (error) {
      partialPublicationFailureSurfaced = error instanceof SafeFailure
        && error.code === "partial_evidence_already_exists";
    }
    requireCondition(partialPublicationFailureSurfaced, "partial_publication_failure_swallowed_fixture_rejected");
    fs.unlinkSync(fixtureEvidence);

    writeExclusiveDurable(fixtureEvidence, [
      "INTERMEDIATE_PHASE|APPROVED",
      "HOSTED_AUTH_CONCURRENCY_BOUNDARIES|REJECTED|fixture_failure",
    ]);
    requireCondition(fs.existsSync(fixtureEvidence), "intermediate_approved_partial_fixture_rejected");
    fs.unlinkSync(fixtureEvidence);
    let contradictionRejected = false;
    try {
      writeExclusiveDurable(fixtureEvidence, [
        "HOSTED_AUTH_CONCURRENCY_BOUNDARIES|APPROVED",
        "HOSTED_AUTH_CONCURRENCY_BOUNDARIES|REJECTED|fixture_failure",
      ]);
    } catch (error) {
      contradictionRejected = error instanceof SafeFailure && error.code === "evidence_approved_rejected_conflict";
    }
    requireCondition(contradictionRejected && !fs.existsSync(fixtureEvidence), "evidence_contradiction_fixture_rejected");
    requireCondition(
      fs.readdirSync(fixtureRoot).filter((name) => name.includes(".next")).length === 0,
      "evidence_temporary_survivor_fixture_rejected",
    );
  } finally {
    if (fs.existsSync(fixtureRoot)) fs.rmSync(fixtureRoot, { recursive: true, force: true });
  }

  const previousExitCode = process.exitCode;
  const previousConnection = runtimeState.databaseConnection;
  const previousFactory = createSupabaseClient;
  try {
    const abortCredentials = { projectUrl: "fixture", publicKey: "fixture", serviceKey: "fixture", adminAPassword: "fixture", adminBPassword: "fixture", targetPassword: "fixture" };
    runtimeState.databaseConnection = Object.freeze({ fixture: true });
    createSupabaseClient = () => Object.freeze({ fixture: true });
    finishControlledExit(abortCredentials, OPERATOR_ABORT_EXIT_CODE);
    requireCondition(
      process.exitCode === OPERATOR_ABORT_EXIT_CODE
        && Object.values(abortCredentials).every((value) => value === "")
        && runtimeState.databaseConnection === null
        && createSupabaseClient === null,
      "controlled_abort_fixture_rejected",
    );
    const successCredentials = { projectUrl: "fixture", publicKey: "fixture", serviceKey: "fixture", adminAPassword: "fixture", adminBPassword: "fixture", targetPassword: "fixture" };
    finishControlledExit(successCredentials, 0);
    requireCondition(process.exitCode === 0 && Object.values(successCredentials).every((value) => value === ""), "controlled_success_fixture_rejected");
  } finally {
    process.exitCode = previousExitCode;
    runtimeState.databaseConnection = previousConnection;
    createSupabaseClient = previousFactory;
  }

  const mainSource = normalizeEol(main.toString());
  const evidenceReconciliationPosition = mainSource.indexOf("reconcileEvidencePublication");
  const databaseConnectionPosition = mainSource.indexOf("parsePostgresConnectionUri");
  const handlerBaselinePosition = mainSource.indexOf('authHandlerContractSql("AUTH_HANDLER_BASELINE_SQL")');
  const lfOrder = assertMainIrreversibleOrder(mainSource);
  const crlfOrder = assertMainIrreversibleOrder(mainSource.replaceAll("\n", "\r\n"));
  requireCondition(
    evidenceReconciliationPosition >= 0
      && databaseConnectionPosition > evidenceReconciliationPosition
      && handlerBaselinePosition > databaseConnectionPosition
      && lfOrder.firstConfirmation > handlerBaselinePosition
      && JSON.stringify(lfOrder) === JSON.stringify(crlfOrder),
    "main_boundary_order_fixture_rejected",
  );
  const v2OrderFixture = `async function main() {
    const listedAuthUsers = await listAllAuthUsers(serviceClient);
    const listedAuthUserIds = validateListedAuthUserIds(listedAuthUsers);
    const detailedAuthUsers = await loadDetailedAuthUsers(serviceClient, listedAuthUserIds);
    validateDetailedAuthInventory(listedAuthUserIds, detailedAuthUsers);
    requireDetailedFixtureAdmins(detailedAuthUsers, adminA.id, adminB.id);
    const target = selectDetailedTargetC(detailedAuthUsers);
    await signInExact(targetClient, target.email, password, target.id, "target_login_failed");
    await refreshExact(adminAClient, adminASession, adminA.id, "admin_a_refresh_failed");
    await refreshExact(adminBClient, adminBSession, adminB.id, "admin_b_refresh_failed");
    if (!await readConfirmation("CONTINUE_B3A_CONCURRENCY_BOUNDARIES")) return;
    executeTransactionalSql(connection, case17OrdinaryUsersSql(), "CASE17_SQL");
    const ordinaryStart = await edgeResponse(targetClient, payload);
    const ordinaryRetry = await edgeResponse(targetClient, retryPayload);
    executeTransactionalSql(connection, case18ServiceRoleSql(adminA.id, targetId), "CASE18_SQL");
    await verifyServiceRolePostgrestBoundary(serviceClient);
    if (!await readConfirmation("CONTINUE_B3A_CONCURRENCY_BOUNDARIES_IRREVERSIBLE")) return;
    runtimeState.irreversible = true;
    createSyntheticAuthoritySql(authorityId, authorityEmail, adminA.id);
    publishEvidencePair(evidencePath, postcheckPath, evidenceLines, postcheckLines);
  }`;
  let v2OrderRejected = false;
  try {
    assertMainIrreversibleOrder(v2OrderFixture);
  } catch (error) {
    v2OrderRejected = error instanceof SafeFailure
      && ["main_boundary_order_fixture_rejected", "main_irreversible_boundary_fixture_rejected"].includes(error.code);
  }
  requireCondition(v2OrderRejected, "main_v2_order_negative_fixture_rejected");
  requireCondition(
    (mainSource.match(/coordinateWorkerPair\(/g) ?? []).length === 4
      && (mainSource.match(/coordinateAuthorityLoss\(/g) ?? []).length === 3
      && mainSource.includes("runtimeState.advisoryObservations === REQUIRED_ADVISORY_OBSERVATIONS")
      && mainSource.indexOf('authHandlerContractSql("AUTH_HANDLER_POSTCHECK_SQL")') > lfOrder.authority,
    "main_observation_and_handler_fixture_rejected",
  );
  requireCondition(
    !mainSource.includes("terminal_failure")
      && !mainSource.includes("auth.admin.createUser"),
    "main_irreversible_boundary_fixture_rejected",
  );
  console.log("B3A_HOSTED_AUTH_CONCURRENCY_BOUNDARIES_FIXTURES|APPROVED");
}

function loadLocalContracts(repoRoot) {
  const reconciliationRoot = path.join(repoRoot, "supabase", "reconciliation");
  const evidenceHashes = validateRequiredEvidence(reconciliationRoot);
  validatePackageHashes(repoRoot);
  const users = parseFixtureUsers(readRequiredText(
    path.join(reconciliationRoot, "b3a_matrix_hosted_auth_users.local.txt"),
    "fixture_users_missing",
  ));
  return Object.freeze({
    reconciliationRoot,
    evidenceHashes,
    adminA: users.get("admin_a"),
    adminB: users.get("admin_b"),
  });
}

function assertNoCurrentEvidence(evidencePath, postcheckPath) {
  requireCondition(!fs.existsSync(evidencePath) && !fs.existsSync(postcheckPath), "concurrency_evidence_already_exists");
  const directory = path.dirname(evidencePath);
  const names = fs.readdirSync(directory);
  requireCondition(
    !names.some((name) => name.startsWith("b3a_matrix_hosted_auth_concurrency_boundaries") && name.includes(".next")),
    "concurrency_evidence_temporary_present",
  );
}

async function main({ readOnlyProbeOnly = false } = {}) {
  const repoRoot = path.resolve(process.env.SITAA_B3A_REPO_ROOT ?? "");
  requireCondition(repoRoot.length > 0 && process.cwd() === repoRoot, "repository_root_required");
  requireCondition((process.env.SITAA_B3A_PROJECT_REF ?? "") === EXPECTED_PROJECT_REF, "project_ref_rejected");
  requireCondition(process.version === EXPECTED_NODE_VERSION, "node_version_rejected");
  const { reconciliationRoot, adminA, adminB } = loadLocalContracts(repoRoot);
  const evidencePath = path.join(reconciliationRoot, "b3a_matrix_hosted_auth_concurrency_boundaries.local.txt");
  const postcheckPath = path.join(reconciliationRoot, "b3a_matrix_hosted_auth_concurrency_boundaries_postcheck.local.txt");
  reconcileEvidencePublication(evidencePath, postcheckPath, {
    recoverOrphanPostcheck: !readOnlyProbeOnly,
  });
  runtimeState.evidencePath = evidencePath;
  runtimeState.postcheckPath = postcheckPath;
  const connection = parsePostgresConnectionUri(process.env.SITAA_B3A_DB_URL ?? "");
  runtimeState.databaseConnection = connection;
  const baselineApprovedAt = utcNow();
  const baseline = parseBaseline(executeReadOnlySql(
    connection,
    baselineSql(adminA.id, adminB.id),
    "CONCURRENCY_BOUNDARIES_BASELINE",
  ));
  parseAuthHandlerContract(executeReadOnlySql(
    connection,
    authHandlerContractSql("AUTH_HANDLER_BASELINE_SQL"),
    "AUTH_HANDLER_BASELINE_SQL",
  ), "AUTH_HANDLER_BASELINE_SQL");
  recordApprovedPhase("AUTH_HANDLER_BASELINE|APPROVED");
  if (readOnlyProbeOnly) {
    console.log(`HARNESS_VERSION|${HARNESS_VERSION}`);
    console.log("BASELINE|APPROVED");
    console.log("AUTH_HANDLER_BASELINE|APPROVED");
    console.log("READ_ONLY_TRANSACTION|true");
    console.log("ROLLBACK|true");
    runtimeState.databaseConnection = null;
    return;
  }

  const supabaseJsVersion = await loadSupabaseJs(repoRoot);
  const credentials = {
    projectUrl: (await readMasked("Project URL exacta: ")).trim(),
    publicKey: validatePublicApiKey((await readMasked("Publishable/anon key: ")).trim()),
    serviceKey: validatePrivilegedApiKey((await readMasked("Service role/secret key: ")).trim()),
    adminAPassword: await readMasked("Contraseña de Admin A: "),
    adminBPassword: await readMasked("Contraseña de Admin B: "),
    targetPassword: await readMasked("Contraseña de Target C preaprovisionado: "),
  };
  runtimeState.credentials = credentials;
  requireCondition(credentials.projectUrl === EXPECTED_PROJECT_URL, "project_url_rejected");
  requireCondition(
    credentials.adminAPassword.length > 0 && credentials.adminBPassword.length > 0 && credentials.targetPassword.length > 0,
    "credentials_required",
  );
  const adminAClient = createIsolatedClient(credentials.projectUrl, credentials.publicKey);
  const adminBClient = createIsolatedClient(credentials.projectUrl, credentials.publicKey);
  const targetClient = createIsolatedClient(credentials.projectUrl, credentials.publicKey);
  const serviceClient = createIsolatedClient(credentials.projectUrl, credentials.serviceKey);
  let adminASession = await signInExact(adminAClient, adminA.email, credentials.adminAPassword, adminA.id, "admin_a_login_failed");
  let adminBSession = await signInExact(adminBClient, adminB.email, credentials.adminBPassword, adminB.id, "admin_b_login_failed");
  const listedAuthUsers = await listAllAuthUsers(serviceClient);
  const listedAuthUserIds = validateListedAuthUserIds(listedAuthUsers);
  const detailedAuthUsers = await loadDetailedAuthUsers(serviceClient, listedAuthUserIds);
  const authDetailCounts = validateDetailedAuthInventory(listedAuthUserIds, detailedAuthUsers);
  console.log(formatAuthDetailDiagnostic(authDetailCounts));
  requireDetailedFixtureAdmins(detailedAuthUsers, adminA.id, adminB.id);
  const target = selectDetailedTargetC(detailedAuthUsers);
  const targetId = target.id;
  const targetEmail = target.email.toLowerCase();
  requireCondition(
    UUID_PATTERN.test(targetId)
      && TARGET_EMAIL_PATTERN.test(targetEmail)
      && target.email_confirmed_at
      && !authBanIsActive(target)
      && target.app_metadata?.sitaa_account_kind === "technical"
      && target.app_metadata?.sitaa_first_names === TARGET_FIRST_NAMES,
    "target_auth_contract_rejected",
  );
  runtimeState.targetId = targetId;
  await signInExact(targetClient, targetEmail, credentials.targetPassword, targetId, "target_login_failed");
  adminASession = await refreshExact(adminAClient, adminASession, adminA.id, "admin_a_refresh_failed");
  adminBSession = await refreshExact(adminBClient, adminBSession, adminB.id, "admin_b_refresh_failed");
  void adminASession;
  void adminBSession;

  if (!await readConfirmation(
    "CONTINUE_B3A_CONCURRENCY_BOUNDARIES",
    "Escribe CONTINUE_B3A_CONCURRENCY_BOUNDARIES para preparar fixtures transaccionales.",
  )) {
    console.log("HOSTED_AUTH_CONCURRENCY_BOUNDARIES|ABORTED");
    finishControlledExit(credentials, OPERATOR_ABORT_EXIT_CODE);
    return;
  }

  runtimeState.phase = "case_17_postgres";
  const case17SqlResult = executeTransactionalSql(connection, case17OrdinaryUsersSql(), "CASE17_SQL");
  requireCondition(case17SqlResult.join("|") === "CASE17_SQL|11|11|1|1", "case17_postgres_rejected");
  const latestOperation = executeReadOnlySql(connection, latestCompletedOperationSql(targetId), "LATEST_COMPLETED_OPERATION");
  requireCondition(latestOperation.length === 5 && UUID_PATTERN.test(latestOperation[1]) && latestOperation.slice(3).join("|") === "succeeded|completed", "latest_operation_rejected");

  runtimeState.phase = "case_18_postgres";
  const case18SqlResult = executeTransactionalSql(
    connection,
    case18ServiceRoleSql(adminA.id, targetId),
    "CASE18_SQL",
  );
  requireCondition(case18SqlResult.join("|") === "CASE18_SQL|15|1|1|1|1", "case18_sql_boundary_rejected");

  if (!await readConfirmation(
    "CONTINUE_B3A_CONCURRENCY_BOUNDARIES_IRREVERSIBLE",
    "Escribe CONTINUE_B3A_CONCURRENCY_BOUNDARIES_IRREVERSIBLE para persistir operaciones B.3a y ejecutar Auth Admin.",
  )) {
    console.log("HOSTED_AUTH_CONCURRENCY_BOUNDARIES|ABORTED");
    finishControlledExit(credentials, OPERATOR_ABORT_EXIT_CODE);
    return;
  }
  runtimeState.irreversible = true;
  runtimeState.advisoryObservations = 0;
  const irreversibleStartedAt = utcNow();
  assertNoCurrentEvidence(evidencePath, postcheckPath);

  runtimeState.phase = "case_17_hosted_boundary";
  const case17Before = executeReadOnlySql(connection, profileAndLedgerSnapshotSql(targetId, "CASE17_EDGE_BEFORE"), "CASE17_EDGE_BEFORE");
  const ordinaryStart = await edgeResponse(targetClient, buildStartPayload(
    targetId,
    "deactivate",
    "Intento ordinario Hosted Auth caso diecisiete",
    crypto.randomUUID(),
  ));
  const ordinaryRetry = await edgeResponse(targetClient, buildRetryPayload(latestOperation[1]));
  requireCondition(
    ordinaryStart.httpStatus === 403
      && ordinaryStart.data.code === "authorization_lost"
      && ordinaryStart.data.state === "rejected"
      && ordinaryStart.data.operationId === null
      && ordinaryRetry.httpStatus === 403
      && ordinaryRetry.data.code === "authorization_lost"
      && ordinaryRetry.data.state === "pending"
      && ordinaryRetry.data.operationId === latestOperation[1],
    "case17_hosted_boundary_rejected",
  );
  const case17After = executeReadOnlySql(connection, profileAndLedgerSnapshotSql(targetId, "CASE17_EDGE_AFTER"), "CASE17_EDGE_AFTER");
  requireCondition(case17Before.slice(1).join("|") === case17After.slice(1).join("|"), "case17_hosted_boundary_mutated_state");
  recordApprovedPhase("CASE_17_ORDINARY_USERS|APPROVED");

  runtimeState.phase = "case_18_hosted_boundary";
  await verifyServiceRolePostgrestBoundary(serviceClient);
  recordApprovedPhase("CASE_18_SERVICE_ROLE_BOUNDARY|APPROVED");

  const runDirectory = path.join(path.dirname(process.argv[1]), "workers");
  fs.mkdirSync(runDirectory, { recursive: false });
  runtimeState.runDirectory = runDirectory;

  runtimeState.phase = "synthetic_authority_creation";
  const authorityId = crypto.randomUUID();
  const authorityEmail = `b3a-authority-d-${crypto.randomBytes(10).toString("hex")}@example.invalid`;
  requireCondition(new RegExp(SYNTHETIC_AUTHORITY_EMAIL_SQL_PATTERN).test(authorityEmail), "synthetic_authority_email_rejected");
  const authorityCreation = executeTransactionalSql(
    connection,
    createSyntheticAuthoritySql(authorityId, authorityEmail, adminA.id),
    "SYNTHETIC_AUTHORITY_CREATED",
  );
  requireCondition(authorityCreation.length === 5 && UUID_PATTERN.test(authorityCreation[1]) && authorityCreation.slice(2).join("|") === "1|1|1", "synthetic_authority_creation_rejected");
  const authorityAssignmentId = authorityCreation[1];
  runtimeState.syntheticAuthorityId = authorityId;
  runtimeState.syntheticAuthorityAssignmentId = authorityAssignmentId;

  runtimeState.phase = "same_request_same_payload";
  const deactivationRequestId = crypto.randomUUID();
  const deactivationReason = "Prueba final de concurrencia y lease B.3a";
  const sameRequest = await coordinateWorkerPair(connection, {
    holderSql: holderPrepareSql(adminA.id, targetId, deactivationRequestId, "deactivate", deactivationReason),
    waiterSql: waiterPrepareSameSql(adminA.id, targetId, deactivationRequestId, "deactivate", `  ${deactivationReason}  `),
    holderName: "same-request-holder",
    waiterName: "same-request-waiter",
    runDirectory,
  });
  const holderPrepared = parseMarkerLine(sameRequest.holderLines, "HOLDER_READY", 3);
  const waiterPrepared = parseMarkerLine(sameRequest.waiterLines, "WAITER_RESULT", 3);
  requireCondition(UUID_PATTERN.test(holderPrepared[1]) && holderPrepared[1] === waiterPrepared[1], "same_request_operation_mismatch");
  const deactivationOperationId = holderPrepared[1];
  const preparedContract = executeReadOnlySql(
    connection,
    verifyPreparedOperationSql(deactivationOperationId, adminA.id, targetId, deactivationRequestId, "deactivate", deactivationReason),
    "PREPARED_OPERATION_CONTRACT",
  );
  requireCondition(preparedContract.join("|") === "PREPARED_OPERATION_CONTRACT|1|1|1", "same_request_database_contract_rejected");
  recordApprovedPhase("SAME_REQUEST_SAME_PAYLOAD|APPROVED");

  runtimeState.phase = "request_conflict";
  const conflictPair = await coordinateWorkerPair(connection, {
    holderSql: advisoryHolderSql(),
    waiterSql: waiterPrepareErrorSql(
      adminA.id,
      targetId,
      deactivationRequestId,
      "deactivate",
      `${deactivationReason} distinto`,
      "23505",
      "sitaa_auth_operation_request_id_conflict",
      "REQUEST_CONFLICT_RESULT",
    ),
    holderName: "request-conflict-holder",
    waiterName: "request-conflict-waiter",
    runDirectory,
  });
  requireCondition(parseMarkerLine(conflictPair.waiterLines, "REQUEST_CONFLICT_RESULT", 3)[1] === "approved", "request_conflict_rejected");
  recordApprovedPhase("SAME_REQUEST_DIFFERENT_PAYLOAD|APPROVED");

  runtimeState.phase = "target_busy";
  const busyPair = await coordinateWorkerPair(connection, {
    holderSql: advisoryHolderSql(),
    waiterSql: waiterPrepareErrorSql(
      adminA.id,
      targetId,
      crypto.randomUUID(),
      "reactivate",
      "Solicitud concurrente contra el mismo objetivo",
      "55000",
      "sitaa_auth_operation_target_busy",
      "TARGET_BUSY_RESULT",
    ),
    holderName: "target-busy-holder",
    waiterName: "target-busy-waiter",
    runDirectory,
  });
  requireCondition(parseMarkerLine(busyPair.waiterLines, "TARGET_BUSY_RESULT", 3)[1] === "approved", "target_busy_rejected");
  recordApprovedPhase("SAME_TARGET_DIFFERENT_REQUEST|APPROVED");

  runtimeState.phase = "authority_loss_claim";
  await setSyntheticAuthority(connection, authorityId, authorityAssignmentId, true);
  const authorityClaimBefore = executeReadOnlySql(connection, operationSnapshotSql(targetId, deactivationOperationId, "AUTHORITY_CLAIM_BEFORE"), "AUTHORITY_CLAIM_BEFORE");
  await coordinateAuthorityLoss(connection, {
    holderName: "authority-claim-holder",
    waiterName: "authority-claim-waiter",
    waiterSql: authorityLossClaimSql(authorityId, deactivationOperationId, "AUTHORITY_LOSS_CLAIM_RESULT"),
    resultPrefix: "AUTHORITY_LOSS_CLAIM_RESULT",
    authorityId,
    assignmentId: authorityAssignmentId,
    runDirectory,
  });
  const authorityClaimAfter = executeReadOnlySql(connection, operationSnapshotSql(targetId, deactivationOperationId, "AUTHORITY_CLAIM_AFTER"), "AUTHORITY_CLAIM_AFTER");
  requireCondition(authorityClaimBefore.slice(1).join("|") === authorityClaimAfter.slice(1).join("|"), "authority_loss_claim_mutated_state");

  runtimeState.phase = "initial_lease_claim";
  const firstClaim = await claimOperation(serviceClient, deactivationOperationId, adminA.id, true);
  requireCondition(firstClaim.attemptCount === 1 && firstClaim.completedStage === "profile_suspended", "initial_lease_claim_rejected");
  const leaseBefore = parseLeaseOperationState(
    executeReadOnlySql(
      connection,
      leaseOperationStateSql(deactivationOperationId, "LEASE_RECOVERY_BEFORE"),
      "LEASE_RECOVERY_BEFORE",
    ),
    "LEASE_RECOVERY_BEFORE",
    deactivationOperationId,
  );
  requireCondition(leaseBefore.attemptCount === 1, "initial_lease_state_rejected");
  const freshClaim = await claimOperation(serviceClient, deactivationOperationId, adminB.id, false);
  requireCondition(freshClaim.attemptCount === 1 && freshClaim.updatedAt === firstClaim.updatedAt, "fresh_lease_reclaimed");
  recordApprovedPhase("FRESH_LEASE_NOT_RECLAIMED|APPROVED");

  runtimeState.phase = "lease_wait";
  const leaseWait = await waitForLeaseExpiration(connection);
  runtimeState.phase = "post_lock_recovered_claim";
  const recoveredClaimPair = await coordinateWorkerPair(connection, {
    holderSql: advisoryHolderSql(),
    waiterSql: claimWaiterSql(adminB.id, deactivationOperationId),
    holderName: "claim-clock-holder",
    waiterName: "claim-clock-waiter",
    runDirectory,
  });
  const recoveredClaimParts = parseMarkerLine(recoveredClaimPair.waiterLines, "CLAIM_RESULT", 7);
  requireCondition(
    recoveredClaimParts[1] === deactivationOperationId
      && recoveredClaimParts[2] === "2"
      && recoveredClaimParts[3] === "t"
      && Date.parse(recoveredClaimParts[4]) >= Date.parse(leaseWait.finishedAt)
      && Date.parse(recoveredClaimParts[4]) >= Date.parse(recoveredClaimPair.holderReleasedAt)
      && Date.parse(recoveredClaimParts[4]) > Date.parse(recoveredClaimPair.waiterStartedAt)
      && Date.parse(recoveredClaimParts[5]) >= Date.parse(recoveredClaimParts[4]),
    "post_lock_recovered_claim_clock_rejected",
  );
  const leaseAfter = parseLeaseOperationState(
    executeReadOnlySql(
      connection,
      leaseOperationStateSql(deactivationOperationId, "LEASE_RECOVERY_AFTER"),
      "LEASE_RECOVERY_AFTER",
    ),
    "LEASE_RECOVERY_AFTER",
    deactivationOperationId,
  );
  requireCondition(
    recoveredLeasePostcheckApproved(
      leaseBefore,
      leaseAfter,
      leaseWait.finishedAt,
      recoveredClaimPair.holderReleasedAt,
      recoveredClaimPair.waiterStartedAt,
    ),
    "lease_recovery_postcheck_rejected",
  );
  const recoveredClaim = Object.freeze({
    operationId: deactivationOperationId,
    targetId,
    transition: "deactivate",
    status: "processing",
    completedStage: leaseAfter.stage,
    attemptCount: leaseAfter.attemptCount,
    retryable: false,
    lastErrorCode: null,
    updatedAt: leaseAfter.updatedAt,
    claimed: true,
  });
  recordApprovedPhase("LEASE_RECOVERY_POSTCHECK|APPROVED");

  runtimeState.phase = "authority_loss_record";
  await setSyntheticAuthority(connection, authorityId, authorityAssignmentId, true);
  const authorityRecordBefore = executeReadOnlySql(connection, operationSnapshotSql(targetId, deactivationOperationId, "AUTHORITY_RECORD_BEFORE"), "AUTHORITY_RECORD_BEFORE");
  await coordinateAuthorityLoss(connection, {
    holderName: "authority-record-holder",
    waiterName: "authority-record-waiter",
    waiterSql: authorityLossRecordSql(authorityId, deactivationOperationId, 2),
    resultPrefix: "AUTHORITY_LOSS_RECORD_RESULT",
    authorityId,
    assignmentId: authorityAssignmentId,
    runDirectory,
  });
  const authorityRecordAfter = executeReadOnlySql(connection, operationSnapshotSql(targetId, deactivationOperationId, "AUTHORITY_RECORD_AFTER"), "AUTHORITY_RECORD_AFTER");
  requireCondition(authorityRecordBefore.slice(1).join("|") === authorityRecordAfter.slice(1).join("|"), "authority_loss_record_mutated_state");

  runtimeState.phase = "attempt_fencing";
  const staleBefore = authorityRecordAfter;
  const staleResult = await authRequest(() => serviceClient.rpc("record_admin_auth_operation_result_b3a", {
    requested_operation_id: deactivationOperationId,
    caller_profile_id: adminA.id,
    claimed_attempt_count: 1,
    requested_result: "auth_succeeded",
    stable_error_code: null,
  }), "stale_attempt_request_failed");
  requireCondition(databaseErrorMatches(staleResult.error, "55000", "sitaa_auth_operation_stale_attempt"), "stale_attempt_not_rejected");
  const staleAfter = executeReadOnlySql(connection, operationSnapshotSql(targetId, deactivationOperationId, "STALE_ATTEMPT_AFTER"), "STALE_ATTEMPT_AFTER");
  requireCondition(staleBefore.slice(1).join("|") === staleAfter.slice(1).join("|"), "stale_attempt_mutated_state");

  runtimeState.phase = "deactivation_auth";
  const deactivationAuth = await updateAuthBan(serviceClient, targetId, "876000h", true);
  requireCondition(deactivationAuth.authCalls === 1, "deactivation_auth_call_count_rejected");
  const deactivationCompleted = await recordOperationResult(serviceClient, recoveredClaim, adminB.id, "auth_succeeded", null);
  requireCondition(deactivationCompleted.status === "succeeded" && deactivationCompleted.completedStage === "completed", "deactivation_result_rejected");

  runtimeState.phase = "authority_loss_final_replay";
  await setSyntheticAuthority(connection, authorityId, authorityAssignmentId, true);
  const finalReplayBefore = executeReadOnlySql(connection, operationSnapshotSql(targetId, deactivationOperationId, "FINAL_REPLAY_BEFORE"), "FINAL_REPLAY_BEFORE");
  await coordinateAuthorityLoss(connection, {
    holderName: "authority-final-holder",
    waiterName: "authority-final-waiter",
    waiterSql: authorityLossClaimSql(authorityId, deactivationOperationId, "AUTHORITY_LOSS_FINAL_REPLAY_RESULT"),
    resultPrefix: "AUTHORITY_LOSS_FINAL_REPLAY_RESULT",
    authorityId,
    assignmentId: authorityAssignmentId,
    runDirectory,
  });
  const finalReplayAfter = executeReadOnlySql(connection, operationSnapshotSql(targetId, deactivationOperationId, "FINAL_REPLAY_AFTER"), "FINAL_REPLAY_AFTER");
  requireCondition(finalReplayBefore.slice(1).join("|") === finalReplayAfter.slice(1).join("|"), "authority_loss_final_replay_mutated_state");

  runtimeState.phase = "auth_synchronized_recovery";
  const reactivationRequestId = crypto.randomUUID();
  const reactivationReason = "Recuperación inmediata auth synchronized B.3a";
  const preparedReactivation = await prepareOperation(adminAClient, targetId, "reactivate", reactivationReason, reactivationRequestId);
  requireCondition(
    !preparedReactivation.error
      && preparedReactivation.operation?.status === "open"
      && preparedReactivation.operation.completedStage === "prepared"
      && preparedReactivation.operation.attemptCount === 0,
    "reactivation_prepare_rejected",
  );
  const reactivationOperationId = preparedReactivation.operation.operationId;
  const reactivationClaim = await claimOperation(serviceClient, reactivationOperationId, adminA.id, true);
  requireCondition(reactivationClaim.attemptCount === 1, "reactivation_claim_rejected");
  const restoredAuth = await updateAuthBan(serviceClient, targetId, "none", false);
  const authAfterUpdate = authFingerprint(restoredAuth.user);
  const synchronized = await recordOperationResult(serviceClient, reactivationClaim, adminA.id, "auth_succeeded", null);
  requireCondition(synchronized.status === "processing" && synchronized.completedStage === "auth_synchronized", "reactivation_sync_rejected");
  const recovered = await edgeResponse(adminBClient, buildRetryPayload(reactivationOperationId));
  requireCondition(
    recovered.data.code === "account_reactivated"
      && recovered.data.state === "completed"
      && recovered.data.operationId === reactivationOperationId,
    "auth_synchronized_edge_recovery_rejected",
  );
  const authAfterRecovery = authFingerprint(await exactAdminUser(serviceClient, targetId));
  requireCondition(authAfterRecovery === authAfterUpdate, "auth_repeated_during_recovery");
  const recoveryState = executeReadOnlySql(
    connection,
    reactivationRecoverySql(
      reactivationOperationId,
      deactivationOperationId,
      targetId,
      adminA.id,
      adminB.id,
      baseline,
    ),
    "AUTH_SYNCHRONIZED_RECOVERY_STATE",
  );
  requireCondition(
    recoveryState.join("|") === "AUTH_SYNCHRONIZED_RECOVERY_STATE|1|1|1|1",
    "auth_synchronized_recovery_state_rejected",
  );

  if (runtimeState.syntheticAuthorityEnabled) await setSyntheticAuthority(connection, authorityId, authorityAssignmentId, false);
  stopAllWorkers();
  removeRunDirectory(runDirectory);
  runtimeState.runDirectory = null;
  requireCondition(runtimeState.liveWorkers.size === 0, "live_workers_remaining");

  runtimeState.phase = "final_postcheck";
  const postcheck = executeReadOnlySql(
    connection,
    finalPostcheckSql(targetId, adminA.id, adminB.id, authorityId, authorityAssignmentId, baseline),
    "CONCURRENCY_BOUNDARIES_POSTCHECK",
  );
  parseFinalPostcheck(postcheck);
  parseAuthHandlerContract(executeReadOnlySql(
    connection,
    authHandlerContractSql("AUTH_HANDLER_POSTCHECK_SQL"),
    "AUTH_HANDLER_POSTCHECK_SQL",
  ), "AUTH_HANDLER_POSTCHECK_SQL");
  requireCondition(
    runtimeState.advisoryObservations === REQUIRED_ADVISORY_OBSERVATIONS,
    "mandatory_advisory_observations_incomplete",
  );
  const completedAt = utcNow();
  const evidenceLines = [
    `HARNESS_VERSION|${HARNESS_VERSION}`,
    `NODE_RUNTIME|${process.version}`,
    `SUPABASE_JS_VERSION|${supabaseJsVersion}`,
    `BASELINE_APPROVED_UTC|${baselineApprovedAt}`,
    `IRREVERSIBLE_STARTED_UTC|${irreversibleStartedAt}`,
    `MATRIX_COMPLETED_UTC|${completedAt}`,
    "BASELINE|APPROVED",
    "AUTH_HANDLER_BASELINE|APPROVED",
    "CASE_17_ORDINARY_USERS|APPROVED",
    "CASE_18_SERVICE_ROLE_BOUNDARY|APPROVED",
    "SERVICE_ROLE_AUDIT_ACL|SELECT_INSERT_ONLY",
    "SAME_REQUEST_SAME_PAYLOAD|APPROVED",
    "SAME_REQUEST_DIFFERENT_PAYLOAD|APPROVED",
    "SAME_TARGET_DIFFERENT_REQUEST|APPROVED",
    "ADVISORY_LOCK_WAIT_OBSERVED|true",
    `ADVISORY_LOCK_OBSERVATIONS|${REQUIRED_ADVISORY_OBSERVATIONS}/${REQUIRED_ADVISORY_OBSERVATIONS}`,
    "WAITER_STARTED_BEFORE_RELEASE|true",
    "PROCESSING_STARTED_AFTER_LOCK|true",
    "UPDATED_AT_MONOTONIC|true",
    "LATEST_OPERATION_ORDER|APPROVED",
    "FRESH_LEASE_NOT_RECLAIMED|true",
    "LEASE_RECOVERED_AFTER_5_MINUTES|true",
    "STALE_ATTEMPT_REJECTED|APPROVED",
    "CURRENT_ATTEMPT_ACCEPTED|APPROVED",
    "AUTHORITY_LOSS_CLAIM|APPROVED",
    "AUTHORITY_LOSS_RECORD|APPROVED",
    "AUTHORITY_LOSS_FINAL_REPLAY|APPROVED",
    "AUTH_SYNCHRONIZED_RECOVERY|APPROVED",
    "AUTH_CALLS_DURING_RECOVERY|1",
    "AUTH_REPEATED_DURING_RECOVERY|false",
    "REQUESTER_FINALIZER_DISTINCT|true",
    "B1_ACTIVE_AUTHORITY|2/2",
    "BASELINE_ADMIN_ASSIGNMENTS_PRESERVED|true",
    `PERSISTENT_DELTA_AUTH_USERS|+${EXPECTED_DELTA.authUsers}`,
    `PERSISTENT_DELTA_AUTH_IDENTITIES|+${EXPECTED_DELTA.authIdentities}`,
    `PERSISTENT_DELTA_PROFILES|+${EXPECTED_DELTA.profiles}`,
    `PERSISTENT_DELTA_ROLE_ASSIGNMENTS|+${EXPECTED_DELTA.roleAssignments}`,
    `PERSISTENT_DELTA_OPERATIONS|+${EXPECTED_DELTA.operations}`,
    `PERSISTENT_DELTA_ADMIN_EVENTS|+${EXPECTED_DELTA.administrativeEvents}`,
    `PERSISTENT_DELTA_AUTH_SUCCESS_EVENTS|+${EXPECTED_DELTA.authSuccessEvents}`,
    `PERSISTENT_DELTA_AUTH_FAILURE_EVENTS|+${EXPECTED_DELTA.authFailureEvents}`,
    "HOSTED_AUTH_CONCURRENCY_BOUNDARIES|APPROVED",
  ];
  const postcheckLines = [
    `HARNESS_VERSION|${HARNESS_VERSION}`,
    "AUTH_USERS|4",
    "AUTH_IDENTITIES|3",
    "PROFILES|4",
    "ROLE_ASSIGNMENTS|3",
    "B1_ACTIVE_AUTHORITY|2/2",
    "TARGET_C_ACTIVE|true",
    "TARGET_C_BANNED|false",
    "TARGET_C_ASSIGNMENTS|0",
    "B3A_OPERATIONS|6",
    "B3A_SUCCEEDED_COMPLETED|6",
    "B3A_NONFINAL|0",
    "B3A_NONSUCCEEDED|0",
    "B3A_ADMIN_EVENTS|12",
    "B3A_AUTH_FAILURE_EVENTS|0",
    "B3A_AUTH_SUCCESS_EVENTS|6",
    "BASELINE_ADMIN_ASSIGNMENTS_PRESERVED|true",
    "SYNTHETIC_AUTHORITY_ACTIVE|false",
    "ACTIVE_LEASES|0",
    "LIVE_WORKERS|0",
    "AUTH_HANDLER_STATE|CANONICAL",
    "READ_ONLY_TRANSACTION|true",
    "ROLLBACK|true",
    "HOSTED_AUTH_CONCURRENCY_BOUNDARIES_POSTCHECK|APPROVED",
  ];
  assertNoCurrentEvidence(evidencePath, postcheckPath);
  publishEvidencePair(evidencePath, postcheckPath, evidenceLines, postcheckLines);
  console.log("HOSTED_AUTH_CONCURRENCY_BOUNDARIES|APPROVED");
  finishControlledExit(credentials, 0);
}

async function handleFailure(error) {
  const rawCode = error instanceof SafeFailure ? error.code : "unexpected_failure";
  const safeCode = /^[a-z][a-z0-9_]{0,79}$/.test(rawCode) && !containsForbiddenEvidence(rawCode)
    ? rawCode
    : "unexpected_failure";
  stopAllWorkers();
  if (runtimeState.irreversible
      && runtimeState.databaseConnection
      && runtimeState.syntheticAuthorityId
      && runtimeState.syntheticAuthorityAssignmentId) {
    try {
      await setSyntheticAuthority(
        runtimeState.databaseConnection,
        runtimeState.syntheticAuthorityId,
        runtimeState.syntheticAuthorityAssignmentId,
        false,
      );
    } catch {
      // La evidencia parcial conserva el fallo; no se oculta ni se amplía la mutación.
    }
  }
  if (runtimeState.runDirectory) {
    try { removeRunDirectory(runtimeState.runDirectory); } catch { /* limpieza best effort */ }
    runtimeState.runDirectory = null;
  }
  let reportedCode = safeCode;
  if (runtimeState.irreversible
      && runtimeState.evidencePath
      && runtimeState.postcheckPath
      && !fs.existsSync(runtimeState.evidencePath)
      && !fs.existsSync(runtimeState.postcheckPath)) {
    const partial = [
      `HARNESS_VERSION|${HARNESS_VERSION}`,
      `FAILURE_PHASE|${/^[a-z][a-z0-9_]{0,79}$/.test(runtimeState.phase) ? runtimeState.phase : "unknown"}`,
      `FAILURE_CODE|${safeCode}`,
      ...runtimeState.approvedPhases,
    ];
    if (runtimeState.databaseConnection && runtimeState.targetId && runtimeState.syntheticAuthorityId) {
      try {
        const diagnostic = executeReadOnlySql(
          runtimeState.databaseConnection,
          failureDiagnosticSql(runtimeState.targetId, runtimeState.syntheticAuthorityId),
          "FAILURE_DIAGNOSTIC",
        );
        requireCondition(diagnostic.length === 8, "failure_diagnostic_shape_rejected");
        partial.push("FAILURE_DIAGNOSTIC|RECORDED");
        partial.push(`DIAGNOSTIC_OPERATIONS|${diagnostic[1]}`);
        partial.push(`DIAGNOSTIC_NONFINAL|${diagnostic[2]}`);
        partial.push(`DIAGNOSTIC_NONSUCCEEDED|${diagnostic[3]}`);
        partial.push(`DIAGNOSTIC_ADMIN_EVENTS|${diagnostic[4]}`);
        partial.push(`DIAGNOSTIC_TARGET_ACTIVE|${diagnostic[5]}`);
        partial.push(`DIAGNOSTIC_TARGET_UNBANNED|${diagnostic[6]}`);
        partial.push(`DIAGNOSTIC_SYNTHETIC_AUTHORITY_ACTIVE|${diagnostic[7]}`);
        partial.push("DIAGNOSTIC_READ_ONLY_TRANSACTION|true");
        partial.push("DIAGNOSTIC_ROLLBACK|true");
      } catch {
        partial.push("FAILURE_DIAGNOSTIC|UNAVAILABLE");
      }
    }
    partial.push(`HOSTED_AUTH_CONCURRENCY_BOUNDARIES|REJECTED|${safeCode}`);
    try {
      publishPartialEvidence(runtimeState.evidencePath, partial);
    } catch {
      reportedCode = "partial_evidence_publication_failed";
    }
  }
  console.error(`HOSTED_AUTH_CONCURRENCY_BOUNDARIES|REJECTED|${reportedCode}`);
  clearCollectedCredentials(runtimeState.credentials);
  runtimeState.credentials = null;
  runtimeState.databaseConnection = null;
  createSupabaseClient = null;
  process.exitCode = 1;
}

const repoRoot = path.resolve(process.env.SITAA_B3A_REPO_ROOT ?? "");
try {
  if (process.argv.includes("--self-test")) {
    requireCondition(repoRoot.length > 0, "repository_root_required");
    await runSelfTests(repoRoot);
  } else if (process.argv.includes("--read-only-probe")) {
    await main({ readOnlyProbeOnly: true });
  } else {
    await main();
  }
} catch (error) {
  if (process.argv.includes("--self-test")) {
    console.error("B3A_HOSTED_AUTH_CONCURRENCY_BOUNDARIES_FIXTURES|REJECTED");
    process.exitCode = 1;
  } else {
    await handleFailure(error);
  }
}
'@

function Assert-TemporaryPath {
  param(
    [Parameter(Mandatory = $true)][string]$Candidate,
    [Parameter(Mandatory = $true)][string]$RepositoryRoot
  )

  $resolvedCandidate = [System.IO.Path]::GetFullPath($Candidate)
  $resolvedRepository = [System.IO.Path]::GetFullPath($RepositoryRoot).TrimEnd('\')
  $expectedPrefix = $resolvedRepository + '\.sitaa-b3a-concurrency-runtime-'
  if (-not $resolvedCandidate.StartsWith($expectedPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "temporary_path_rejected"
  }
}

function Assert-ScriptEncoding {
  param([Parameter(Mandatory = $true)][string]$Path)

  $bytes = [System.IO.File]::ReadAllBytes($Path)
  if ($bytes.Length -lt 3 -or $bytes[0] -ne 0xEF -or $bytes[1] -ne 0xBB -or $bytes[2] -ne 0xBF) {
    throw "script_utf8_bom_required"
  }
  for ($index = 3; $index -lt $bytes.Length; $index += 1) {
    if ($bytes[$index] -eq 0x0A -and ($index -eq 0 -or $bytes[$index - 1] -ne 0x0D)) {
      throw "script_crlf_required"
    }
    if ($bytes[$index] -eq 0x0D -and ($index + 1 -ge $bytes.Length -or $bytes[$index + 1] -ne 0x0A)) {
      throw "script_crlf_required"
    }
  }
}

function Assert-PowerShellSyntax {
  param([Parameter(Mandatory = $true)][string]$Path)

  $tokens = $null
  $errors = $null
  [void][System.Management.Automation.Language.Parser]::ParseFile(
    $Path,
    [ref]$tokens,
    [ref]$errors
  )
  if ($errors.Count -ne 0) {
    throw "powershell_parser_rejected"
  }
}

function Get-EvidenceFingerprint {
  param([Parameter(Mandatory = $true)][string]$RepositoryRoot)

  $reconciliationRoot = Join-Path $RepositoryRoot "supabase\reconciliation"
  $fingerprints = @{}
  foreach ($name in $protectedLocalArtifactNames) {
    $artifactPath = Join-Path $reconciliationRoot $name
    if (Test-Path -LiteralPath $artifactPath -PathType Leaf) {
      $item = Get-Item -LiteralPath $artifactPath
      $hash = (Get-FileHash -LiteralPath $artifactPath -Algorithm SHA256).Hash.ToLowerInvariant()
      $fingerprints[$name] = "present|$($item.Length)|$hash"
    }
    else {
      $fingerprints[$name] = "absent"
    }
  }
  return $fingerprints
}

function Assert-FingerprintsEqual {
  param(
    [Parameter(Mandatory = $true)][hashtable]$Before,
    [Parameter(Mandatory = $true)][hashtable]$After
  )

  foreach ($name in $protectedLocalArtifactNames) {
    if (-not $Before.ContainsKey($name) -or -not $After.ContainsKey($name) -or $Before[$name] -ne $After[$name]) {
      throw "protected_evidence_changed"
    }
  }
}

function Resolve-PsqlExecutable {
  $resolved = Get-Command "psql.exe" -CommandType Application -ErrorAction SilentlyContinue |
    Select-Object -First 1
  if ($null -eq $resolved) {
    throw "psql_executable_required"
  }
  $path = if ($resolved.Path) { $resolved.Path } else { $resolved.Source }
  if ([string]::IsNullOrWhiteSpace($path) -or -not (Test-Path -LiteralPath $path -PathType Leaf)) {
    throw "psql_executable_required"
  }
  return [System.IO.Path]::GetFullPath($path)
}

$modeCount = @($ValidateOnly.IsPresent, $ReadOnlyProbeOnly.IsPresent) |
  Where-Object { $_ } |
  Measure-Object |
  Select-Object -ExpandProperty Count
if ($modeCount -gt 1) {
  throw "execution_mode_rejected"
}
if (-not $currentRoot.Equals($repoRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
  throw "repository_root_rejected"
}

Assert-ScriptEncoding -Path $PSCommandPath
$protectedBefore = Get-EvidenceFingerprint -RepositoryRoot $repoRoot
Assert-TemporaryPath -Candidate $temporaryRoot -RepositoryRoot $repoRoot

try {
  [System.IO.Directory]::CreateDirectory($temporaryRoot) | Out-Null
  $utf8WithoutBom = New-Object System.Text.UTF8Encoding($false)
  [System.IO.File]::WriteAllText($nodeModulePath, $nodeModule, $utf8WithoutBom)
  $env:SITAA_B3A_REPO_ROOT = $repoRoot

  if ($ValidateOnly) {
    Assert-PowerShellSyntax -Path $PSCommandPath
    & node --check $nodeModulePath
    if ($LASTEXITCODE -ne 0) {
      throw "embedded_node_syntax_rejected"
    }
    & node $nodeModulePath --self-test
    if ($LASTEXITCODE -ne 0) {
      throw "embedded_fixture_rejected"
    }
    $protectedAfter = Get-EvidenceFingerprint -RepositoryRoot $repoRoot
    Assert-FingerprintsEqual -Before $protectedBefore -After $protectedAfter
    Write-Output "B3A_HOSTED_AUTH_CONCURRENCY_BOUNDARIES_STATIC_VALIDATION|APPROVED"
    return
  }

  $packagePath = Join-Path $repoRoot "node_modules\@supabase\supabase-js\package.json"
  if (-not (Test-Path -LiteralPath $packagePath -PathType Leaf)) {
    throw "supabase_js_package_required"
  }
  if ([string]::IsNullOrWhiteSpace($env:SITAA_B3A_PROJECT_REF)) {
    throw "project_ref_required"
  }
  if ([string]::IsNullOrWhiteSpace($env:SITAA_B3A_DB_URL)) {
    throw "database_url_required"
  }
  $env:SITAA_B3A_PSQL_PATH = Resolve-PsqlExecutable

  if ($ReadOnlyProbeOnly) {
    & node $nodeModulePath --read-only-probe
  }
  else {
    & node $nodeModulePath
  }
  $nodeExitCode = $LASTEXITCODE
  if ($ReadOnlyProbeOnly) {
    $protectedAfter = Get-EvidenceFingerprint -RepositoryRoot $repoRoot
    Assert-FingerprintsEqual -Before $protectedBefore -After $protectedAfter
  }
  if ($nodeExitCode -eq 2) {
    exit 2
  }
  if ($nodeExitCode -ne 0) {
    throw "hosted_auth_concurrency_boundaries_rejected"
  }
}
finally {
  Remove-Item Env:SITAA_B3A_REPO_ROOT -ErrorAction SilentlyContinue
  Remove-Item Env:SITAA_B3A_PSQL_PATH -ErrorAction SilentlyContinue
  if (Test-Path -LiteralPath $temporaryRoot) {
    Assert-TemporaryPath -Candidate $temporaryRoot -RepositoryRoot $repoRoot
    Remove-Item -LiteralPath $temporaryRoot -Recurse -Force
  }
}
