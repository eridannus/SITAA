param(
  [switch]$ValidateOnly,
  [switch]$ReadOnlyProbeOnly,
  [switch]$ResumeExistingTarget,
  [switch]$RestoreConfirmationOnly
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$scriptRoot = Split-Path -Parent $PSCommandPath
$repoRoot = [System.IO.Path]::GetFullPath((Join-Path $scriptRoot ".."))
$currentRoot = [System.IO.Path]::GetFullPath((Get-Location).Path)
$temporaryRoot = [System.IO.Path]::GetFullPath(
  (Join-Path $repoRoot (".sitaa-b3a-failure-runtime-" + [guid]::NewGuid().ToString("N")))
)
$nodeModulePath = Join-Path $temporaryRoot "hosted-auth-failure-recovery.mjs"
$protectedLocalArtifactNames = @(
  "b3a_matrix_hosted_auth_failure_recovery.local.txt",
  "b3a_matrix_hosted_auth_failure_recovery_postcheck.local.txt",
  "b3a_matrix_hosted_auth_failure_recovery_confirmation_repair.local.txt"
)

$nodeModule = @'
import crypto from "node:crypto";
import fs from "node:fs";
import path from "node:path";
import process from "node:process";
import readline from "node:readline/promises";
import { spawnSync } from "node:child_process";

const EXPECTED_PROJECT_REF = "upttfqjogltvymnaubkg";
const EXPECTED_PROJECT_URL = `https://${EXPECTED_PROJECT_REF}.supabase.co`;
const HARNESS_VERSION = "2026-08-03-hosted-auth-failure-recovery-v3";
const EXPECTED_SUPABASE_JS_VERSION = "2.110.1";
const OPERATOR_ABORT_EXIT_CODE = 2;
const POSTGRES_PROCESS_TIMEOUT_MS = 45_000;
const POSTGRES_MAX_BUFFER_BYTES = 1024 * 1024;
const DEFAULT_POSTGRES_PORT = 5432;
const POSTGRES_SSL_MODES = new Set(["require", "verify-ca", "verify-full"]);
const CORE_EVIDENCE = Object.freeze({
  name: "b3a_matrix_hosted_auth_core.local.txt",
  bytes: 2008,
  sha256: "55315c6e4b9c34278d920f231bac48c7349a1f9da3b0d3d7e2516c90e2ea7cac",
  marker: "HOSTED_AUTH_CORE_MATRIX|APPROVED",
});
const CORE_POSTCHECK_EVIDENCE = Object.freeze({
  name: "b3a_matrix_hosted_auth_core_postcheck.local.txt",
  bytes: 333,
  sha256: "29c38e45dd6b8b5ae3aec4dd57380aef46c1ed198e89be03b1a45477ed49a389",
  marker: "B3A_CORE_POSTCHECK|APPROVED",
});
const EXPECTED_EDGE_HASHES = new Map([
  ["index.ts", "5d7118a339f7854519c064c205453bb505f1a7b19185d62bc9177e696a774ad5"],
  ["auth-admin-adapter.ts", "83acccb558c03564b36512d772f84adb8e7b58157efbd592e5e253b7befd4bef"],
]);
const EXPECTED_ADMIN_ALIASES = new Set(["admin_a", "admin_b"]);
const TARGET_EMAIL_PATTERN = "b3a-failure-target-%@example.invalid";
const TARGET_FIRST_NAMES = "Objetivo técnico matriz de fallos C";
const UUID_PATTERN =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const HASH_PATTERN = /^[0-9a-f]{32,64}$/i;
const FORBIDDEN_EVIDENCE =
  /@|https?:|bearer|authorization|cookie|password|secret|service[_-]?role|access[_-]?token|refresh[_-]?token|eyj[a-z0-9_-]*\./i;
const SAFE_EVIDENCE_TERMS = ["service_boundary_contract"];
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
const PSQL_ARGUMENTS = Object.freeze([
  "-X", "-qAt", "-w", "-v", "ON_ERROR_STOP=1", "-f", "-",
]);
const READ_ONLY_PREFIXES = new Set([
  "FAILURE_RECOVERY_BASELINE",
  "FAILURE_TARGET_CONTRACT",
  "AUTH_FAILURE_STATE",
  "OPERATION_SNAPSHOT",
  "AUTH_FAILURE_RECOVERED",
  "REACTIVATION_SYNCHRONIZED",
  "FINALIZATION_FAILURE_STATE",
  "SECOND_ADMIN_RECOVERY_STATE",
  "FAILURE_RECOVERY_POSTCHECK",
  "FAILURE_RECOVERY_DIAGNOSTIC",
  "TARGET_CONFIRMATION_RESTORED_CHECK",
  "CONFIRMATION_REPAIR_BASELINE",
]);
const FAILURE_PHASES = new Set([
  "before_first_confirmation",
  "target_creation",
  "before_second_confirmation",
  "auth_failure_injection",
  "request_replays",
  "auth_failure_recovery",
  "reactivation_auth_sync",
  "finalization_failure_injection",
  "confirmation_restoration",
  "second_admin_recovery",
  "final_postcheck",
]);
const B3A_AUTH_ACTIONS = [
  "account_auth_suspended",
  "account_auth_restored",
  "account_auth_suspension_failed",
  "account_auth_restoration_failed",
];
const B3A_ALL_ACTIONS = [
  "account_deactivated",
  "account_reactivated",
  ...B3A_AUTH_ACTIONS,
];

const runtimeState = {
  phase: "before_first_confirmation",
  evidencePersisted: false,
  evidencePath: null,
  databaseConnection: null,
  targetId: null,
  originalEmailConfirmedAt: null,
  confirmationNeedsRestoration: false,
  confirmationRestoredVerified: false,
  confirmationRestoreOutcome: null,
  repairPath: null,
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
  return value.replace(/\r\n?/g, "\n");
}

function exactObject(value, keys) {
  if (typeof value !== "object" || value === null || Array.isArray(value)) return false;
  const actual = Object.keys(value).sort();
  const expected = [...keys].sort();
  return actual.length === expected.length
    && actual.every((key, index) => key === expected[index]);
}

function oneRow(value) {
  return Array.isArray(value) && value.length === 1
    && typeof value[0] === "object" && value[0] !== null
    ? value[0]
    : null;
}

function containsForbiddenEvidence(line) {
  const filtered = SAFE_EVIDENCE_TERMS.reduce(
    (value, term) => value.replaceAll(term, ""),
    line,
  );
  return FORBIDDEN_EVIDENCE.test(filtered);
}

function assertSafeEvidenceLine(line) {
  requireCondition(
    /^[A-Za-z0-9_./:=|-]+$/.test(line) && !containsForbiddenEvidence(line),
    "unsafe_evidence_rejected",
  );
  return line;
}

function utcNow() {
  const value = new Date().toISOString();
  requireCondition(
    /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z$/.test(value),
    "utc_timestamp_invalid",
  );
  return value;
}

function hashBuffer(value) {
  return crypto.createHash("sha256").update(value).digest("hex");
}

function readRequiredBuffer(filePath, failureCode) {
  requireCondition(fs.existsSync(filePath), failureCode);
  return fs.readFileSync(filePath);
}

function readRequiredText(filePath, failureCode) {
  return normalizeEol(readRequiredBuffer(filePath, failureCode).toString("utf8"));
}

function validateExactEvidence(reconciliationRoot, contract) {
  const buffer = readRequiredBuffer(
    path.join(reconciliationRoot, contract.name),
    "central_evidence_missing",
  );
  requireCondition(buffer.length === contract.bytes, "central_evidence_size_rejected");
  requireCondition(hashBuffer(buffer) === contract.sha256, "central_evidence_hash_rejected");
  requireCondition(buffer.toString("utf8").includes(contract.marker), "central_evidence_marker_rejected");
}

function validateCanonicalEdge(repoRoot) {
  const edgeRoot = path.join(
    repoRoot,
    "supabase",
    "functions",
    "admin-account-auth-lifecycle",
  );
  for (const [fileName, expectedHash] of EXPECTED_EDGE_HASHES) {
    const buffer = readRequiredBuffer(path.join(edgeRoot, fileName), "canonical_edge_source_missing");
    requireCondition(hashBuffer(buffer) === expectedHash, "canonical_edge_source_drift");
  }
}

function readSupabaseJsVersion(repoRoot) {
  let rootPackage;
  let installedPackage;
  try {
    rootPackage = JSON.parse(readRequiredText(path.join(repoRoot, "package.json"), "root_package_missing"));
    installedPackage = JSON.parse(readRequiredText(
      path.join(repoRoot, "node_modules", "@supabase", "supabase-js", "package.json"),
      "supabase_js_package_missing",
    ));
  } catch (error) {
    if (error instanceof SafeFailure) throw error;
    fail("package_version_invalid");
  }
  const declared = rootPackage?.dependencies?.["@supabase/supabase-js"];
  const normalizedDeclared = typeof declared === "string" ? declared.replace(/^[~^]/, "") : "";
  requireCondition(
    normalizedDeclared === EXPECTED_SUPABASE_JS_VERSION
      && installedPackage?.version === EXPECTED_SUPABASE_JS_VERSION,
    "supabase_js_version_rejected",
  );
  return installedPackage.version;
}

async function loadSupabaseJs(repoRoot) {
  const version = readSupabaseJsVersion(repoRoot);
  let module;
  try {
    module = await import("@supabase/supabase-js");
  } catch {
    fail("supabase_js_package_missing");
  }
  requireCondition(typeof module?.createClient === "function", "supabase_js_export_invalid");
  createSupabaseClient = module.createClient;
  return version;
}

function createIsolatedClient(projectUrl, key) {
  requireCondition(typeof createSupabaseClient === "function", "supabase_js_not_loaded");
  return createSupabaseClient(projectUrl, key, CLIENT_OPTIONS);
}

function sqlLiteralUuid(value) {
  requireCondition(UUID_PATTERN.test(value), "invalid_fixture_uuid");
  return `'${value}'::uuid`;
}

function sqlLiteralText(value) {
  requireCondition(typeof value === "string" && value.length > 0, "invalid_fixture_text");
  return `'${value.replace(/'/g, "''")}'::text`;
}

function sqlLiteralTimestamp(value) {
  requireCondition(
    typeof value === "string" && Number.isFinite(Date.parse(value)),
    "invalid_fixture_timestamp",
  );
  return `'${value.replace(/'/g, "''")}'::timestamptz`;
}

function parseFixtureUsers(contents) {
  const rows = contents.split("\n").map((line) => line.trim())
    .filter((line) => line.startsWith("AUTH_CREATED|"));
  requireCondition(rows.length === 2, "fixture_user_count_invalid");
  const users = new Map();
  for (const row of rows) {
    const fields = row.split("|");
    requireCondition(fields.length === 4, "fixture_user_shape_invalid");
    const [, alias, email, id] = fields;
    requireCondition(EXPECTED_ADMIN_ALIASES.has(alias) && !users.has(alias), "fixture_alias_invalid");
    requireCondition(
      /^[a-z0-9][a-z0-9._+-]*@example\.invalid$/.test(email),
      "fixture_email_invalid",
    );
    requireCondition(UUID_PATTERN.test(id), "fixture_uuid_invalid");
    users.set(alias, { email, id });
  }
  requireCondition(users.get("admin_a").id !== users.get("admin_b").id, "fixture_users_not_distinct");
  return users;
}

function parsePostgresConnectionUri(dbUrl) {
  requireCondition(typeof dbUrl === "string" && dbUrl.length > 0, "database_url_rejected");
  let parsed;
  try {
    parsed = new URL(dbUrl);
  } catch {
    fail("database_url_rejected");
  }
  requireCondition(
    parsed.protocol === "postgresql:" || parsed.protocol === "postgres:",
    "database_url_rejected",
  );
  requireCondition(parsed.hostname.length > 0, "database_url_rejected");
  requireCondition(parsed.username.length > 0 && parsed.password.length > 0, "database_url_rejected");
  requireCondition(parsed.hash === "", "database_url_rejected");
  const decode = (value) => {
    try {
      return decodeURIComponent(value);
    } catch {
      fail("database_url_rejected");
    }
  };
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
  const identityTokens = `${username}.${parsed.hostname}`.toLowerCase()
    .split(/[^a-z0-9]+/).filter(Boolean);
  requireCondition(identityTokens.includes(EXPECTED_PROJECT_REF), "database_url_rejected");
  return Object.freeze({
    hostname: parsed.hostname,
    port: String(port),
    username,
    password,
    database,
    sslmode,
  });
}

function postgresChildEnvironment(connection, sourceEnvironment = process.env) {
  const environment = {};
  for (const [key, value] of Object.entries(sourceEnvironment)) {
    const upperKey = key.toUpperCase();
    if (upperKey.startsWith("SITAA_B3A_")) continue;
    if (POSTGRES_ENVIRONMENT_KEYS.has(upperKey)) continue;
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
    PGOPTIONS: "-c statement_timeout=30000 -c lock_timeout=5000",
    PGAPPNAME: "sitaa_b3a_failure_recovery",
    PGCLIENTENCODING: "UTF8",
    PG_COLOR: "never",
  });
  return environment;
}

function classifyPsqlFailure(result) {
  if (result?.error?.code === "ETIMEDOUT") return "database_process_timeout";
  const stderr = String(result?.stderr ?? "");
  if (/password authentication failed|no password supplied|password (?:is )?required|fe_sendauth|contraseña/i.test(stderr)) {
    return "database_password_unavailable";
  }
  if (result?.status === 0 && !result?.error) return null;
  if (result?.status === 2) return "database_connection_failed";
  if (result?.status === 3) return "database_script_failed";
  return "database_check_failed";
}

function spawnPsql(connection, sql) {
  return spawnSync("psql", PSQL_ARGUMENTS, {
    cwd: process.env.SITAA_B3A_REPO_ROOT,
    encoding: "utf8",
    env: postgresChildEnvironment(connection),
    input: `${normalizeEol(sql).trim()}\n`,
    windowsHide: true,
    timeout: POSTGRES_PROCESS_TIMEOUT_MS,
    maxBuffer: POSTGRES_MAX_BUFFER_BYTES,
  });
}

function parsePsqlMarker(result, expectedPrefix) {
  const failureCode = classifyPsqlFailure(result);
  if (failureCode) fail(failureCode);
  const lines = normalizeEol(String(result.stdout ?? "")).split("\n")
    .map((line) => line.trim()).filter(Boolean);
  const matches = lines.filter((line) => line.startsWith(`${expectedPrefix}|`));
  requireCondition(matches.length === 1, "database_result_invalid");
  return matches[0].split("|");
}

function executeReadOnlySql(connection, sql, expectedPrefix) {
  requireCondition(READ_ONLY_PREFIXES.has(expectedPrefix), "database_prefix_rejected");
  const normalized = normalizeEol(sql).trim();
  requireCondition(/^begin;\nset transaction read only;/i.test(normalized), "sql_not_read_only");
  requireCondition(/\nrollback;$/i.test(normalized), "sql_missing_rollback");
  requireCondition(
    !/\b(insert|update|delete|alter|drop|truncate|grant|revoke|create|call|do)\b/i.test(
      normalized.replace(/'[^']*'/g, "''"),
    ),
    "sql_contains_write",
  );
  console.log(`POSTGRES_READ_ONLY_GATE|${expectedPrefix}|STARTED`);
  const parsed = parsePsqlMarker(spawnPsql(connection, normalized), expectedPrefix);
  console.log(`POSTGRES_READ_ONLY_GATE|${expectedPrefix}|APPROVED`);
  return parsed;
}

function executeConfirmationMutation(connection, sql, expectedPrefix) {
  requireCondition(
    expectedPrefix === "TARGET_CONFIRMATION_CLEARED"
      || expectedPrefix === "TARGET_CONFIRMATION_RESTORED",
    "confirmation_mutation_prefix_rejected",
  );
  const normalized = normalizeEol(sql).trim();
  const withoutStrings = normalized.replace(/'[^']*'/g, "''");
  requireCondition(/^begin;/i.test(normalized) && /\ncommit;$/i.test(normalized), "confirmation_mutation_transaction_invalid");
  requireCondition((withoutStrings.match(/\bupdate\s+auth\.users\b/gi) ?? []).length === 1, "confirmation_mutation_scope_rejected");
  requireCondition(/set\s+email_confirmed_at\s*=/i.test(withoutStrings), "confirmation_mutation_column_rejected");
  requireCondition(!/\b(insert|delete|alter|drop|truncate|grant|revoke|create|call)\b/i.test(withoutStrings), "confirmation_mutation_write_rejected");
  return parsePsqlMarker(spawnPsql(connection, normalized), expectedPrefix);
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
        if (character === "\u007f" || character === "\b") {
          const current = Array.from(value);
          if (current.length > 0) {
            current.pop();
            value = current.join("");
            process.stdout.write("\b \b");
          }
          return;
        }
        const characters = Array.from(character);
        if (characters.length === 0 || characters.some((entry) => /[\p{Cc}\p{Cf}\p{Cs}]/u.test(entry))) {
          process.stdin.off("data", onData);
          reject(new SafeFailure("masked_input_invalid_character"));
          return;
        }
        value += character;
        process.stdout.write("*".repeat(characters.length));
      };
      process.stdin.on("data", onData);
    });
  } finally {
    process.stdin.setRawMode(false);
    process.stdin.pause();
  }
}

async function readConfirmation(expected) {
  const prompt = readline.createInterface({ input: process.stdin, output: process.stdout });
  const value = await prompt.question("> ");
  prompt.close();
  return value === expected;
}

function baselineSql(adminAId, adminBId) {
  const adminA = sqlLiteralUuid(adminAId);
  const adminB = sqlLiteralUuid(adminBId);
  const allActions = B3A_ALL_ACTIONS.map((value) => sqlLiteralText(value)).join(",");
  const authActions = B3A_AUTH_ACTIONS.map((value) => sqlLiteralText(value)).join(",");
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
)
select concat_ws('|','FAILURE_RECOVERY_BASELINE',
  (select count(*) from auth.users),
  (select count(*) from auth.identities),
  (select count(*) from public.profiles),
  (select count(*) from public.role_assignments),
  (select count(*) from public.profiles p where p.id in (${adminA},${adminB})
    and p.account_status='active' and p.is_active
    and public.is_exact_b1_account_admin_profile_b2b(p.id)),
  (select count(*) from public.admin_auth_operations),
  (select count(*) from public.admin_auth_operations where status='succeeded' and completed_stage='completed'),
  (select count(*) from public.admin_auth_operations where status in ('open','processing','retryable_failure')),
  (select count(*) from public.admin_auth_operations where status<>'succeeded'),
  (select count(*) from public.admin_audit_events where action_code in (${allActions})),
  (select count(*) from public.admin_audit_events where action_code in (${authActions}) and outcome='failure'),
  (select count(*) from auth.users where lower(email) like '${TARGET_EMAIL_PATTERN}'),
  (select count(*) from auth.identities identity_row join auth.users auth_user
    on auth_user.id=identity_row.user_id
    where lower(auth_user.email) like '${TARGET_EMAIL_PATTERN}' and identity_row.provider='email'),
  (select count(*) from public.profiles where lower(email) like '${TARGET_EMAIL_PATTERN}'),
  (select count(*) from public.role_assignments assignment join public.profiles profile
    on profile.id=assignment.user_id where lower(profile.email) like '${TARGET_EMAIL_PATTERN}'),
  (select count(*) from public.admin_auth_operations operation join public.profiles profile
    on profile.id=operation.target_profile_id where lower(profile.email) like '${TARGET_EMAIL_PATTERN}'),
  (select count(*) from auth.users auth_user join public.profiles profile on profile.id=auth_user.id
    where lower(auth_user.email) like '${TARGET_EMAIL_PATTERN}'
      and auth_user.email_confirmed_at is not null
      and (auth_user.banned_until is null or auth_user.banned_until<=clock_timestamp())
      and auth_user.raw_app_meta_data->>'sitaa_account_kind'='technical'
      and profile.account_kind='technical' and profile.account_status='active' and profile.is_active
      and profile.first_names=${sqlLiteralText(TARGET_FIRST_NAMES)}
      and profile.full_name=${sqlLiteralText(TARGET_FIRST_NAMES)}
      and profile.activated_at is not null and profile.deactivated_at is null),
  (select count(*) from function_contracts where valid),
  (select count(*) from function_contracts),
  (select count(*) from pg_trigger t where t.tgrelid='public.admin_auth_operations'::regclass
    and not t.tgisinternal and t.tgenabled='O'
    and t.tgfoid='public.guard_admin_auth_operation_b3a()'::regprocedure),
  (select case when c.relrowsecurity and not c.relforcerowsecurity then 1 else 0 end
    from pg_class c where c.oid='public.admin_auth_operations'::regclass),
  (select count(*) from pg_policies where schemaname='public' and tablename='admin_auth_operations')
);
rollback;`;
}

function targetContractSql(targetId, targetEmail) {
  const target = sqlLiteralUuid(targetId);
  const email = sqlLiteralText(targetEmail);
  return `
begin;
set transaction read only;
select concat_ws('|','FAILURE_TARGET_CONTRACT',
  (select count(*) from auth.users),
  (select count(*) from auth.identities),
  (select count(*) from public.profiles),
  (select count(*) from public.role_assignments),
  (select count(*) from auth.users where id=${target} and lower(email)=${email}
    and email_confirmed_at is not null
    and raw_app_meta_data->>'provider'='email'
    and raw_app_meta_data->'providers'='["email"]'::jsonb
    and raw_app_meta_data->>'sitaa_account_kind'='technical'
    and raw_app_meta_data->>'sitaa_first_names'=${sqlLiteralText(TARGET_FIRST_NAMES)}),
  (select count(*) from auth.identities where user_id=${target} and provider='email'
    and lower(identity_data->>'email')=${email}),
  (select count(*) from public.profiles where id=${target} and lower(email)=${email}
    and account_kind='technical' and account_status='active' and is_active
    and first_names=${sqlLiteralText(TARGET_FIRST_NAMES)}
    and full_name=${sqlLiteralText(TARGET_FIRST_NAMES)}
    and activated_at is not null and deactivated_at is null),
  (select count(*) from public.role_assignments where user_id=${target}),
  (select count(*) from public.admin_auth_operations where target_profile_id=${target}),
  coalesce((select activated_at::text from public.profiles where id=${target}),''),
  coalesce((select md5(string_agg(to_jsonb(i)::text,'|' order by i.id))
    from auth.identities i where i.user_id=${target}),''),
  coalesce((select md5(coalesce(string_agg(to_jsonb(r)::text,'|' order by r.id),''))
    from public.role_assignments r where r.user_id=${target}),'')
);
rollback;`;
}

function operationSnapshotSql(targetId) {
  const target = sqlLiteralUuid(targetId);
  const allActions = B3A_ALL_ACTIONS.map((value) => sqlLiteralText(value)).join(",");
  return `
begin;
set transaction read only;
select concat_ws('|','OPERATION_SNAPSHOT',
  (select count(*) from public.admin_auth_operations),
  (select count(*) from public.admin_audit_events where action_code in (${allActions})),
  coalesce((select md5(string_agg(to_jsonb(o)::text,'|' order by o.id))
    from public.admin_auth_operations o where o.target_profile_id=${target}),''),
  coalesce((select md5(string_agg(to_jsonb(a)::text,'|' order by a.id))
    from public.admin_audit_events a where a.target_profile_id=${target}
      and a.action_code in (${allActions})),''));
rollback;`;
}

function authFailureStateSql(targetId, operationId, expectedAttempt, prefix) {
  requireCondition(prefix === "AUTH_FAILURE_STATE" || prefix === "AUTH_FAILURE_RECOVERED", "state_prefix_rejected");
  const target = sqlLiteralUuid(targetId);
  const operation = sqlLiteralUuid(operationId);
  return `
begin;
set transaction read only;
select concat_ws('|',${sqlLiteralText(prefix)},
  (select count(*) from public.profiles where id=${target} and account_status='inactive' and not is_active),
  (select count(*) from auth.users where id=${target} and banned_until is not null and banned_until>clock_timestamp()),
  (select count(*) from public.admin_auth_operations where id=${operation}
    and target_profile_id=${target}
    and attempt_count=${Number(expectedAttempt)}),
  coalesce((select status from public.admin_auth_operations where id=${operation}),''),
  coalesce((select completed_stage from public.admin_auth_operations where id=${operation}),''),
  coalesce((select last_error_code from public.admin_auth_operations where id=${operation}),''),
  (select count(*) from public.admin_audit_events where target_profile_id=${target} and action_code='account_deactivated'),
  (select count(*) from public.admin_audit_events where target_profile_id=${target} and action_code='account_auth_suspension_failed'),
  (select count(*) from public.admin_audit_events where target_profile_id=${target} and action_code='account_auth_suspended')
);
rollback;`;
}

function reactivationSynchronizedSql(targetId, operationId, actorId) {
  const target = sqlLiteralUuid(targetId);
  const operation = sqlLiteralUuid(operationId);
  const actor = sqlLiteralUuid(actorId);
  return `
begin;
set transaction read only;
select concat_ws('|','REACTIVATION_SYNCHRONIZED',
  (select count(*) from public.profiles where id=${target} and account_status='inactive' and not is_active),
  (select count(*) from auth.users where id=${target} and (banned_until is null or banned_until<=clock_timestamp())),
  (select count(*) from public.admin_auth_operations where id=${operation}
    and requested_by_profile_id=${actor} and target_profile_id=${target}
    and operation_code='reactivate' and status='processing'
    and completed_stage='auth_synchronized' and attempt_count=1
    and auth_synchronized_at is not null and auth_audit_event_id is not null),
  coalesce((select auth_synchronized_at::text from public.admin_auth_operations where id=${operation}),''),
  (select count(*) from public.admin_audit_events where target_profile_id=${target} and action_code='account_auth_restored'),
  (select count(*) from public.admin_audit_events where target_profile_id=${target} and action_code='account_auth_restoration_failed')
);
rollback;`;
}

function finalizationFailureSql(targetId, operationId, authSynchronizedAt) {
  const target = sqlLiteralUuid(targetId);
  const operation = sqlLiteralUuid(operationId);
  const synchronizedAt = sqlLiteralTimestamp(authSynchronizedAt);
  return `
begin;
set transaction read only;
select concat_ws('|','FINALIZATION_FAILURE_STATE',
  (select count(*) from public.profiles where id=${target} and account_status='inactive' and not is_active),
  (select count(*) from auth.users where id=${target} and (banned_until is null or banned_until<=clock_timestamp())),
  (select count(*) from public.admin_auth_operations where id=${operation}
    and status='processing' and completed_stage='auth_synchronized'
    and attempt_count=2 and last_error_code is null
    and auth_synchronized_at=${synchronizedAt}),
  (select count(*) from public.admin_audit_events where target_profile_id=${target} and action_code='account_auth_restored'),
  (select count(*) from public.admin_audit_events where target_profile_id=${target} and action_code='account_auth_restoration_failed')
);
rollback;`;
}

function secondAdminRecoverySql(targetId, operationId, adminAId, adminBId, activatedAt, identityHash, assignmentHash) {
  const target = sqlLiteralUuid(targetId);
  const operation = sqlLiteralUuid(operationId);
  const adminA = sqlLiteralUuid(adminAId);
  const adminB = sqlLiteralUuid(adminBId);
  return `
begin;
set transaction read only;
select concat_ws('|','SECOND_ADMIN_RECOVERY_STATE',
  (select count(*) from public.profiles where id=${target} and account_status='active' and is_active
    and activated_at=${sqlLiteralTimestamp(activatedAt)} and deactivated_at is null),
  (select count(*) from auth.users where id=${target} and (banned_until is null or banned_until<=clock_timestamp())),
  (select count(*) from public.admin_auth_operations where id=${operation}
    and requested_by_profile_id=${adminA} and completed_by_profile_id=${adminB}
    and target_profile_id=${target} and operation_code='reactivate'
    and status='succeeded' and completed_stage='completed' and attempt_count=3),
  (select count(*) from public.admin_audit_events where target_profile_id=${target} and action_code='account_reactivated'),
  (select count(*) from public.admin_audit_events where target_profile_id=${target} and action_code='account_auth_restored'),
  (select count(*) from public.admin_audit_events where target_profile_id=${target} and action_code='account_auth_restoration_failed'),
  (select case when coalesce(md5(string_agg(to_jsonb(i)::text,'|' order by i.id)),'')=${sqlLiteralText(identityHash)} then 1 else 0 end
    from auth.identities i where i.user_id=${target}),
  (select case when coalesce(md5(coalesce(string_agg(to_jsonb(r)::text,'|' order by r.id),'')),'')=${sqlLiteralText(assignmentHash)} then 1 else 0 end
    from public.role_assignments r where r.user_id=${target})
);
rollback;`;
}

function finalPostcheckSql(targetId, adminAId, adminBId, expectedEmailConfirmedAt) {
  const target = sqlLiteralUuid(targetId);
  const adminA = sqlLiteralUuid(adminAId);
  const adminB = sqlLiteralUuid(adminBId);
  const allActions = B3A_ALL_ACTIONS.map((value) => sqlLiteralText(value)).join(",");
  const authFailureActions = ["account_auth_suspension_failed", "account_auth_restoration_failed"]
    .map((value) => sqlLiteralText(value)).join(",");
  const authSuccessActions = ["account_auth_suspended", "account_auth_restored"]
    .map((value) => sqlLiteralText(value)).join(",");
  return `
begin;
set transaction read only;
select concat_ws('|','FAILURE_RECOVERY_POSTCHECK',
  (select count(*) from auth.users),
  (select count(*) from auth.identities),
  (select count(*) from public.profiles),
  (select count(*) from public.role_assignments),
  (select count(*) from public.profiles p where public.is_exact_b1_account_admin_profile_b2b(p.id)
    and p.account_status='active' and p.is_active),
  (select count(*) from public.profiles where id=${target} and account_status='active' and is_active),
  (select count(*) from auth.users where id=${target} and (banned_until is null or banned_until<=clock_timestamp())),
  (select count(*) from public.role_assignments where user_id=${target}),
  (select count(*) from public.admin_auth_operations),
  (select count(*) from public.admin_auth_operations where status='succeeded' and completed_stage='completed'),
  (select count(*) from public.admin_auth_operations where status in ('open','processing','retryable_failure')),
  (select count(*) from public.admin_auth_operations where status<>'succeeded'),
  (select count(*) from public.admin_audit_events where action_code in (${allActions})),
  (select count(*) from public.admin_audit_events where action_code in (${authFailureActions}) and outcome='failure'),
  (select count(*) from public.admin_audit_events where target_profile_id=${target} and action_code in (${authSuccessActions}) and outcome='success'),
  (select count(*) from public.admin_audit_events where target_profile_id=${target} and action_code='account_deactivated'),
  (select count(*) from public.admin_audit_events where target_profile_id=${target} and action_code='account_reactivated'),
  (select count(*) from public.admin_audit_events where target_profile_id=${target} and action_code='account_auth_suspension_failed'),
  (select count(*) from public.admin_audit_events where target_profile_id=${target} and action_code='account_auth_restoration_failed'),
  (select count(*) from public.admin_audit_events),
  (select count(*) from public.admin_auth_operations where target_profile_id=${target}
    and operation_code='deactivate' and attempt_count=2
    and requested_by_profile_id=${adminA} and completed_by_profile_id=${adminA}
    and status='succeeded' and completed_stage='completed'),
  (select count(*) from public.admin_auth_operations where target_profile_id=${target}
    and operation_code='reactivate' and attempt_count=3
    and requested_by_profile_id=${adminA} and completed_by_profile_id=${adminB}
    and status='succeeded' and completed_stage='completed'),
  (select count(*) from auth.users where id=${target}
    and email_confirmed_at is not null
    and email_confirmed_at=${sqlLiteralTimestamp(expectedEmailConfirmedAt)})
);
rollback;`;
}

function failureDiagnosticSql(targetId) {
  const target = sqlLiteralUuid(targetId);
  const allActions = B3A_ALL_ACTIONS.map((value) => sqlLiteralText(value)).join(",");
  return `
begin;
set transaction read only;
select concat_ws('|','FAILURE_RECOVERY_DIAGNOSTIC',
  coalesce((select account_status from public.profiles where id=${target}),'missing'),
  (select count(*) from auth.users where id=${target} and banned_until is not null and banned_until>clock_timestamp()),
  (select count(*) from public.admin_auth_operations where target_profile_id=${target}),
  (select count(*) from public.admin_auth_operations where target_profile_id=${target} and status='open'),
  (select count(*) from public.admin_auth_operations where target_profile_id=${target} and status='processing'),
  (select count(*) from public.admin_auth_operations where target_profile_id=${target} and status='retryable_failure'),
  (select count(*) from public.admin_auth_operations where target_profile_id=${target} and status='succeeded'),
  (select count(*) from public.admin_auth_operations where target_profile_id=${target} and status='terminal_failure'),
  (select count(*) from public.admin_auth_operations where target_profile_id=${target} and completed_stage='profile_suspended'),
  (select count(*) from public.admin_auth_operations where target_profile_id=${target} and completed_stage='auth_synchronized'),
  (select count(*) from public.admin_auth_operations where target_profile_id=${target} and completed_stage='completed'),
  (select count(*) from public.admin_audit_events where target_profile_id=${target} and action_code in (${allActions})),
  (select count(*) from auth.users where id=${target} and email_confirmed_at is not null)
);
rollback;`;
}

function clearConfirmationSql(targetId, confirmedAt) {
  return `
begin;
do $sitaa$
declare changed integer;
begin
  update auth.users set email_confirmed_at=null
  where id=${sqlLiteralUuid(targetId)} and email_confirmed_at=${sqlLiteralTimestamp(confirmedAt)};
  get diagnostics changed=row_count;
  if changed<>1 then raise exception 'sitaa_failure_fixture_confirmation_clear_rejected'; end if;
end;
$sitaa$;
select 'TARGET_CONFIRMATION_CLEARED|true';
commit;`;
}

function restoreConfirmationSql(targetId, confirmedAt) {
  return `
begin;
do $sitaa$
declare current_confirmed_at timestamptz;
declare restore_outcome text;
begin
  select email_confirmed_at into strict current_confirmed_at
  from auth.users
  where id=${sqlLiteralUuid(targetId)}
  for update;
  if current_confirmed_at is null then
    update auth.users set email_confirmed_at=${sqlLiteralTimestamp(confirmedAt)}
    where id=${sqlLiteralUuid(targetId)};
    restore_outcome := 'restored';
  elsif current_confirmed_at=${sqlLiteralTimestamp(confirmedAt)} then
    restore_outcome := 'already_restored';
  else
    raise exception using
      errcode='55000',
      message='sitaa_failure_fixture_confirmation_restore_conflict';
  end if;
  perform set_config('sitaa.confirmation_restore_outcome',restore_outcome,true);
end;
$sitaa$;
select 'TARGET_CONFIRMATION_RESTORED|'||current_setting('sitaa.confirmation_restore_outcome');
commit;`;
}

function confirmationRestoredCheckSql(targetId, confirmedAt) {
  return `
begin;
set transaction read only;
select concat_ws('|','TARGET_CONFIRMATION_RESTORED_CHECK',
  (select count(*) from auth.users where id=${sqlLiteralUuid(targetId)}
    and email_confirmed_at=${sqlLiteralTimestamp(confirmedAt)}));
rollback;`;
}

function confirmationRepairBaselineSql(confirmedAt) {
  return `
begin;
set transaction read only;
select concat_ws('|','CONFIRMATION_REPAIR_BASELINE',
  (select count(*) from auth.users where lower(email) like '${TARGET_EMAIL_PATTERN}'),
  (select count(*) from auth.identities identity_row join auth.users auth_user
    on auth_user.id=identity_row.user_id
    where lower(auth_user.email) like '${TARGET_EMAIL_PATTERN}' and identity_row.provider='email'),
  (select count(*) from public.profiles profile join auth.users auth_user
    on auth_user.id=profile.id
    where lower(auth_user.email) like '${TARGET_EMAIL_PATTERN}'
      and profile.account_kind='technical'
      and profile.account_status='inactive'
      and not profile.is_active),
  (select count(*) from public.admin_auth_operations operation join public.profiles profile
    on profile.id=operation.target_profile_id
    where lower(profile.email) like '${TARGET_EMAIL_PATTERN}'
      and operation.operation_code='reactivate'
      and operation.status='processing'
      and operation.completed_stage='auth_synchronized'),
  coalesce((select case
      when auth_user.email_confirmed_at is null then 'needs_restore'
      when auth_user.email_confirmed_at=${sqlLiteralTimestamp(confirmedAt)} then 'already_restored'
      else 'conflict'
    end
    from auth.users auth_user
    where lower(auth_user.email) like '${TARGET_EMAIL_PATTERN}'),'missing'));
rollback;`;
}

function restoreConfirmationFromRepairSql(confirmedAt) {
  return `
begin;
do $sitaa$
declare target uuid;
declare current_confirmed_at timestamptz;
declare restore_outcome text;
begin
  select auth_user.id,auth_user.email_confirmed_at
  into strict target,current_confirmed_at
  from auth.users auth_user
  where lower(auth_user.email) like '${TARGET_EMAIL_PATTERN}'
  for update;
  if (select count(*) from public.admin_auth_operations operation
      where operation.target_profile_id=target
        and operation.operation_code='reactivate'
        and operation.status='processing'
        and operation.completed_stage='auth_synchronized')<>1 then
    raise exception 'sitaa_failure_fixture_repair_operation_rejected';
  end if;
  if current_confirmed_at is null then
    update auth.users set email_confirmed_at=${sqlLiteralTimestamp(confirmedAt)}
    where id=target;
    restore_outcome := 'restored';
  elsif current_confirmed_at=${sqlLiteralTimestamp(confirmedAt)} then
    restore_outcome := 'already_restored';
  else
    raise exception using
      errcode='55000',
      message='sitaa_failure_fixture_confirmation_restore_conflict';
  end if;
  perform set_config('sitaa.confirmation_restore_outcome',restore_outcome,true);
end;
$sitaa$;
select 'TARGET_CONFIRMATION_RESTORED|'||current_setting('sitaa.confirmation_restore_outcome');
commit;`;
}

function confirmationRepairVerifiedSql(confirmedAt) {
  return `
begin;
set transaction read only;
select concat_ws('|','TARGET_CONFIRMATION_RESTORED_CHECK',
  (select count(*) from auth.users where lower(email) like '${TARGET_EMAIL_PATTERN}'
    and email_confirmed_at=${sqlLiteralTimestamp(confirmedAt)}),
  (select count(*) from public.admin_auth_operations operation join public.profiles profile
    on profile.id=operation.target_profile_id
    where lower(profile.email) like '${TARGET_EMAIL_PATTERN}'
      and operation.operation_code='reactivate'
      and operation.status='processing'
      and operation.completed_stage='auth_synchronized'));
rollback;`;
}

function writeConfirmationRepairFile(filePath, confirmedAt) {
  requireCondition(!fs.existsSync(filePath), "confirmation_repair_file_exists");
  const contents = `HARNESS_VERSION|${HARNESS_VERSION}\nEMAIL_CONFIRMED_AT|${confirmedAt}\n`;
  requireCondition(!containsForbiddenEvidence(contents), "confirmation_repair_contents_rejected");
  fs.writeFileSync(filePath, contents, { encoding: "utf8", flag: "wx" });
  requireCondition(
    readConfirmationRepairFile(filePath) === confirmedAt,
    "confirmation_repair_file_verification_rejected",
  );
}

function readConfirmationRepairFile(filePath) {
  const lines = readRequiredText(filePath, "confirmation_repair_file_missing")
    .split("\n").filter(Boolean);
  requireCondition(lines.length === 2, "confirmation_repair_file_invalid");
  requireCondition(lines[0] === `HARNESS_VERSION|${HARNESS_VERSION}`, "confirmation_repair_version_rejected");
  requireCondition(lines[1].startsWith("EMAIL_CONFIRMED_AT|"), "confirmation_repair_timestamp_missing");
  const confirmedAt = lines[1].slice("EMAIL_CONFIRMED_AT|".length);
  requireCondition(Number.isFinite(Date.parse(confirmedAt)), "confirmation_repair_timestamp_invalid");
  return confirmedAt;
}

function classifyConfirmationState(currentConfirmedAt, expectedConfirmedAt) {
  requireCondition(
    typeof expectedConfirmedAt === "string" && Number.isFinite(Date.parse(expectedConfirmedAt)),
    "confirmation_repair_timestamp_invalid",
  );
  if (currentConfirmedAt === null) return "needs_restore";
  if (currentConfirmedAt === expectedConfirmedAt) return "already_restored";
  return "conflict";
}

function parseConfirmationRepairBaseline(parts) {
  const baseline = parseDelimited(parts, "CONFIRMATION_REPAIR_BASELINE", 6);
  requireCondition(
    baseline.slice(1, 5).join("|") === "1|1|1|1"
      && new Set(["needs_restore", "already_restored", "conflict"]).has(baseline[5]),
    "confirmation_repair_baseline_rejected",
  );
  return baseline[5];
}

function removeRepairFileVerified(filePath) {
  requireCondition(typeof filePath === "string" && filePath.length > 0, "confirmation_repair_path_missing");
  try {
    if (fs.existsSync(filePath)) fs.unlinkSync(filePath);
  } catch {
    fail("confirmation_repair_file_cleanup_required");
  }
  requireCondition(!fs.existsSync(filePath), "confirmation_repair_file_cleanup_required");
  return true;
}

function capturedApprovalEvidenceLines(
  baselineApprovedUtc,
  targetContractApprovedUtc,
  irreversibleStartedUtc,
) {
  const timestamps = [baselineApprovedUtc, targetContractApprovedUtc, irreversibleStartedUtc];
  requireCondition(
    timestamps.every((value) => /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z$/.test(value)),
    "captured_approval_timestamp_invalid",
  );
  return [
    `BASELINE_APPROVED_UTC|${baselineApprovedUtc}`,
    `TARGET_CONTRACT_APPROVED_UTC|${targetContractApprovedUtc}`,
    `MATRIX_IRREVERSIBLE_STARTED_UTC|${irreversibleStartedUtc}`,
  ];
}

function parseDelimited(parts, prefix, expectedLength) {
  requireCondition(Array.isArray(parts) && parts.length === expectedLength && parts[0] === prefix, "database_result_shape_invalid");
  return parts;
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
  return {
    operationId: row.operation_id,
    targetId: row.target_profile_id,
    transition: row.operation_code,
    status: row.status,
    completedStage: row.completed_stage,
    attemptCount: row.attempt_count,
    retryable: row.retryable,
    lastErrorCode: row.last_error_code,
    updatedAt: row.updated_at,
  };
}

function parseClaim(data, expectedOperationId) {
  const row = oneRow(data);
  if (!row || !exactObject(row, CLAIM_FIELDS) || typeof row.claimed !== "boolean") return null;
  const snapshotData = [{ ...row }];
  delete snapshotData[0].claimed;
  const snapshot = parseOperationSnapshot(snapshotData, { operationId: expectedOperationId });
  return snapshot ? { ...snapshot, claimed: row.claimed } : null;
}

function databaseErrorMatches(error, code, message) {
  return Boolean(error)
    && String(error.code ?? "") === code
    && String(error.message ?? "").toLowerCase().includes(message.toLowerCase());
}

async function prepareOperation(client, targetId, transition, reason, requestId) {
  const normalizedReason = reason.replace(/\s+/g, " ").trim();
  const result = await client.rpc("prepare_admin_account_auth_lifecycle_b3a", {
    requested_profile_id: targetId,
    requested_transition: transition,
    transition_reason: normalizedReason,
    request_id: requestId,
  });
  return result.error
    ? { error: result.error, operation: null }
    : { error: null, operation: parseOperationSnapshot(result.data, { targetId, transition }) };
}

async function claimOperation(serviceClient, operationId, actorId) {
  const result = await serviceClient.rpc("claim_admin_auth_operation_b3a", {
    requested_operation_id: operationId,
    caller_profile_id: actorId,
  });
  requireCondition(!result.error, "claim_operation_failed");
  const claim = parseClaim(result.data, operationId);
  requireCondition(claim?.claimed === true, "claim_operation_rejected");
  return claim;
}

async function recordOperationResult(serviceClient, operation, actorId, requestedResult, stableErrorCode) {
  const result = await serviceClient.rpc("record_admin_auth_operation_result_b3a", {
    requested_operation_id: operation.operationId,
    caller_profile_id: actorId,
    claimed_attempt_count: operation.attemptCount,
    requested_result: requestedResult,
    stable_error_code: stableErrorCode,
  });
  requireCondition(!result.error, "record_operation_result_failed");
  const snapshot = parseOperationSnapshot(result.data, { operationId: operation.operationId });
  requireCondition(snapshot !== null, "record_operation_result_malformed");
  return snapshot;
}

async function edgeResponse(client, payload) {
  const result = await client.functions.invoke("admin-account-auth-lifecycle", { body: payload });
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
  return { data, hadTransportError: Boolean(result.error), httpStatus };
}

async function signInExact(client, email, password, expectedId, failureCode) {
  const result = await client.auth.signInWithPassword({ email, password });
  requireCondition(!result.error && result.data?.session && result.data?.user, failureCode);
  requireCondition(result.data.user.id === expectedId, "authenticated_user_mismatch");
  return result.data.session;
}

async function refreshExact(client, session, expectedId, failureCode) {
  requireCondition(
    typeof session?.refresh_token === "string" && session.refresh_token.length > 0,
    failureCode,
  );
  const result = await client.auth.refreshSession({ refresh_token: session.refresh_token });
  requireCondition(!result.error && result.data?.session && result.data?.user, failureCode);
  requireCondition(result.data.user.id === expectedId, "refreshed_user_mismatch");
  return result.data.session;
}

async function listAllAuthUsers(serviceClient) {
  const users = [];
  const perPage = 200;
  for (let page = 1; page <= 100; page += 1) {
    const result = await serviceClient.auth.admin.listUsers({ page, perPage });
    requireCondition(!result.error && Array.isArray(result.data?.users), "auth_user_inventory_failed");
    users.push(...result.data.users);
    if (result.data.users.length < perPage) return users;
  }
  fail("auth_user_inventory_unbounded");
}

function isApprovedTargetEmail(value) {
  return typeof value === "string"
    && /^b3a-failure-target-[a-z0-9-]+@example\.invalid$/.test(value.toLowerCase());
}

function stableValue(value) {
  if (Array.isArray(value)) return value.map(stableValue);
  if (value && typeof value === "object") {
    return Object.fromEntries(Object.keys(value).sort().map((key) => [key, stableValue(value[key])]));
  }
  return value;
}

function authFingerprint(user) {
  requireCondition(user && typeof user === "object" && UUID_PATTERN.test(user.id), "auth_fingerprint_input_invalid");
  const sanitized = {
    id: user.id,
    aud: user.aud ?? null,
    role: user.role ?? null,
    email: user.email ?? null,
    phone: user.phone ?? null,
    banned_until: user.banned_until ?? null,
    phone_confirmed_at: user.phone_confirmed_at ?? null,
    created_at: user.created_at ?? null,
    updated_at: user.updated_at ?? null,
    last_sign_in_at: user.last_sign_in_at ?? null,
    app_metadata: user.app_metadata ?? null,
    user_metadata: user.user_metadata ?? null,
    identities: (user.identities ?? []).map((identity) => ({
      id: identity.id ?? null,
      user_id: identity.user_id ?? null,
      provider: identity.provider ?? null,
      identity_data: identity.identity_data ?? null,
      created_at: identity.created_at ?? null,
      updated_at: identity.updated_at ?? null,
      last_sign_in_at: identity.last_sign_in_at ?? null,
    })),
  };
  return hashBuffer(Buffer.from(JSON.stringify(stableValue(sanitized)), "utf8"));
}

async function exactAdminUser(serviceClient, targetId) {
  const result = await serviceClient.auth.admin.getUserById(targetId);
  requireCondition(!result.error && result.data?.user?.id === targetId, "auth_target_lookup_failed");
  return result.data.user;
}

function generateTargetEmail() {
  const stamp = new Date().toISOString().replace(/[-:.TZ]/g, "").toLowerCase();
  const suffix = crypto.randomBytes(6).toString("hex");
  return `b3a-failure-target-${stamp}-${suffix}@example.invalid`;
}

function operationStateEquals(parts, expected) {
  return parts[1] === String(expected.profileInactive)
    && parts[2] === String(expected.banActive)
    && parts[3] === "1"
    && parts[4] === expected.status
    && parts[5] === expected.stage
    && parts[6] === expected.errorCode
    && parts[7] === String(expected.deactivatedEvents)
    && parts[8] === String(expected.failureEvents)
    && parts[9] === String(expected.successEvents);
}

function assertSameSnapshot(before, after, failureCode) {
  requireCondition(before.length === after.length && before.every((value, index) => value === after[index]), failureCode);
}

async function restoreConfirmationIfNeeded() {
  if (!runtimeState.confirmationNeedsRestoration) return runtimeState.confirmationRestoreOutcome;
  requireCondition(
    runtimeState.databaseConnection && runtimeState.targetId && runtimeState.originalEmailConfirmedAt,
    "confirmation_restore_context_missing",
  );
  const restored = parseDelimited(
    executeConfirmationMutation(
      runtimeState.databaseConnection,
      restoreConfirmationSql(runtimeState.targetId, runtimeState.originalEmailConfirmedAt),
      "TARGET_CONFIRMATION_RESTORED",
    ),
    "TARGET_CONFIRMATION_RESTORED",
    2,
  );
  requireCondition(
    restored[1] === "restored" || restored[1] === "already_restored",
    "confirmation_restore_rejected",
  );
  const verified = parseDelimited(
    executeReadOnlySql(
      runtimeState.databaseConnection,
      confirmationRestoredCheckSql(runtimeState.targetId, runtimeState.originalEmailConfirmedAt),
      "TARGET_CONFIRMATION_RESTORED_CHECK",
    ),
    "TARGET_CONFIRMATION_RESTORED_CHECK",
    2,
  );
  requireCondition(verified[1] === "1", "confirmation_restore_verification_rejected");
  runtimeState.confirmationRestoredVerified = true;
  runtimeState.confirmationRestoreOutcome = restored[1];
  runtimeState.confirmationNeedsRestoration = false;
  removeRepairFileVerified(runtimeState.repairPath);
  runtimeState.repairPath = null;
  return restored[1];
}

async function runSelfTests(repoRoot) {
  const adminA = "11111111-1111-4111-8111-111111111111";
  const adminB = "22222222-2222-4222-8222-222222222222";
  const target = "33333333-3333-4333-8333-333333333333";
  const operation = "44444444-4444-4444-8444-444444444444";
  const request = "55555555-5555-4555-8555-555555555555";
  const otherRequest = "66666666-6666-4666-8666-666666666666";
  const confirmedAt = "2026-08-03T12:00:00.000Z";
  const reason = "Prueba sintética de recuperación B.3a";

  requireCondition(readSupabaseJsVersion(repoRoot) === EXPECTED_SUPABASE_JS_VERSION, "self_test_dependency_rejected");
  validateCanonicalEdge(repoRoot);
  const baseline = baselineSql(adminA, adminB);
  const targetContract = targetContractSql(target, "b3a-failure-target-fixture@example.invalid");
  const snapshot = operationSnapshotSql(target);
  const failureState = authFailureStateSql(target, operation, 1, "AUTH_FAILURE_STATE");
  const recoveredState = authFailureStateSql(target, operation, 2, "AUTH_FAILURE_RECOVERED");
  const synchronized = reactivationSynchronizedSql(target, operation, adminA);
  const finalization = finalizationFailureSql(target, operation, confirmedAt);
  const recovery = secondAdminRecoverySql(target, operation, adminA, adminB, confirmedAt, "a".repeat(32), "b".repeat(32));
  const postcheck = finalPostcheckSql(target, adminA, adminB, confirmedAt);
  const diagnostic = failureDiagnosticSql(target);
  const restoredCheck = confirmationRestoredCheckSql(target, confirmedAt);
  const repairBaseline = confirmationRepairBaselineSql(confirmedAt);
  const repairVerified = confirmationRepairVerifiedSql(confirmedAt);
  for (const [sql, prefix] of [
    [baseline, "FAILURE_RECOVERY_BASELINE"],
    [targetContract, "FAILURE_TARGET_CONTRACT"],
    [snapshot, "OPERATION_SNAPSHOT"],
    [failureState, "AUTH_FAILURE_STATE"],
    [recoveredState, "AUTH_FAILURE_RECOVERED"],
    [synchronized, "REACTIVATION_SYNCHRONIZED"],
    [finalization, "FINALIZATION_FAILURE_STATE"],
    [recovery, "SECOND_ADMIN_RECOVERY_STATE"],
    [postcheck, "FAILURE_RECOVERY_POSTCHECK"],
    [diagnostic, "FAILURE_RECOVERY_DIAGNOSTIC"],
    [restoredCheck, "TARGET_CONFIRMATION_RESTORED_CHECK"],
    [repairBaseline, "CONFIRMATION_REPAIR_BASELINE"],
    [repairVerified, "TARGET_CONFIRMATION_RESTORED_CHECK"],
  ]) {
    const normalized = normalizeEol(sql).trim();
    requireCondition(normalized.startsWith("begin;\nset transaction read only;"), "readonly_builder_fixture_failed");
    requireCondition(normalized.endsWith("rollback;"), "readonly_builder_rollback_fixture_failed");
    requireCondition(normalized.includes(`'${prefix}'`), "readonly_builder_prefix_fixture_failed");
  }

  const clearSql = clearConfirmationSql(target, confirmedAt);
  const restoreSql = restoreConfirmationSql(target, confirmedAt);
  const repairRestoreSql = restoreConfirmationFromRepairSql(confirmedAt);
  requireCondition(
    clearSql.includes("update auth.users set email_confirmed_at=null")
      && clearSql.includes(`email_confirmed_at='${confirmedAt}'::timestamptz`)
      && restoreSql.includes(`set email_confirmed_at='${confirmedAt}'::timestamptz`)
      && restoreSql.includes("for update")
      && restoreSql.includes("already_restored")
      && restoreSql.includes("sitaa_failure_fixture_confirmation_restore_conflict")
      && repairRestoreSql.includes(`set email_confirmed_at='${confirmedAt}'::timestamptz`)
      && repairRestoreSql.includes(TARGET_EMAIL_PATTERN)
      && repairRestoreSql.includes("for update")
      && repairRestoreSql.includes("already_restored")
      && !/\b(email\s*=|raw_app_meta_data\s*=|raw_user_meta_data\s*=|encrypted_password\s*=|banned_until\s*=)/i.test(`${clearSql}\n${restoreSql}\n${repairRestoreSql}`),
    "confirmation_restoration_fixture_failed",
  );

  const repairFixturePath = path.join(path.dirname(process.argv[1]), "confirmation-repair-fixture.local.txt");
  const conflictRepairFixturePath = path.join(path.dirname(process.argv[1]), "confirmation-repair-conflict-fixture.local.txt");
  const cleanupFailureFixturePath = path.join(path.dirname(process.argv[1]), "confirmation-repair-cleanup-fixture");
  try {
    writeConfirmationRepairFile(repairFixturePath, confirmedAt);
    requireCondition(
      readConfirmationRepairFile(repairFixturePath) === confirmedAt
        && classifyConfirmationState(confirmedAt, confirmedAt) === "already_restored"
        && removeRepairFileVerified(repairFixturePath)
        && removeRepairFileVerified(repairFixturePath),
      "confirmation_repair_already_restored_fixture_failed",
    );
    writeConfirmationRepairFile(conflictRepairFixturePath, confirmedAt);
    requireCondition(
      classifyConfirmationState(null, confirmedAt) === "needs_restore"
        && classifyConfirmationState("2026-08-03T12:01:00.000Z", confirmedAt) === "conflict"
        && fs.existsSync(conflictRepairFixturePath),
      "confirmation_repair_conflict_fixture_failed",
    );
    fs.mkdirSync(cleanupFailureFixturePath);
    let cleanupFailureCode = null;
    try {
      removeRepairFileVerified(cleanupFailureFixturePath);
    } catch (error) {
      cleanupFailureCode = error instanceof SafeFailure ? error.code : null;
    }
    requireCondition(
      cleanupFailureCode === "confirmation_repair_file_cleanup_required"
        && fs.existsSync(cleanupFailureFixturePath),
      "confirmation_repair_cleanup_failure_fixture_failed",
    );
  } finally {
    if (fs.existsSync(repairFixturePath)) fs.unlinkSync(repairFixturePath);
    if (fs.existsSync(conflictRepairFixturePath)) fs.unlinkSync(conflictRepairFixturePath);
    if (fs.existsSync(cleanupFailureFixturePath)) fs.rmdirSync(cleanupFailureFixturePath);
  }

  const mainSource = main.toString();
  const repairWrittenIndex = mainSource.indexOf("writeConfirmationRepairFile(repairPath, originalEmailConfirmedAt)");
  const restorationArmedIndex = mainSource.indexOf("runtimeState.confirmationNeedsRestoration = true", repairWrittenIndex);
  const clearStartedIndex = mainSource.indexOf("clearConfirmationSql(targetId, originalEmailConfirmedAt)", repairWrittenIndex);
  requireCondition(
    repairWrittenIndex >= 0
      && restorationArmedIndex > repairWrittenIndex
      && clearStartedIndex > restorationArmedIndex,
    "confirmation_pre_clear_repair_window_fixture_failed",
  );
  const restoreOnlySource = restoreConfirmationOnlyMain.toString();
  requireCondition(
    restoreOnlySource.indexOf('repairState !== "conflict"') >= 0
      && restoreOnlySource.indexOf('if (repairState === "needs_restore")')
        > restoreOnlySource.indexOf('repairState !== "conflict"')
      && restoreOnlySource.indexOf("restoreConfirmationFromRepairSql")
        > restoreOnlySource.indexOf('if (repairState === "needs_restore")'),
    "confirmation_repair_mode_branch_fixture_failed",
  );

  const start = buildStartPayload(target, "deactivate", `  ${reason}  `, request);
  const replay = buildStartPayload(target, "deactivate", reason, request);
  const conflict = buildStartPayload(target, "deactivate", `${reason} distinto`, request);
  const busy = buildStartPayload(target, "reactivate", "Nueva solicitud contra operación no final", otherRequest);
  const retry = buildRetryPayload(operation);
  requireCondition(
    exactObject(start, ["mode", "targetProfileId", "transition", "reason", "requestId"])
      && JSON.stringify(start) === JSON.stringify(replay)
      && conflict.requestId === start.requestId && conflict.reason !== start.reason
      && busy.requestId !== start.requestId && busy.targetProfileId === start.targetProfileId
      && exactObject(retry, ["mode", "operationId"]),
    "edge_payload_fixture_failed",
  );

  const countFixture = [
    "FAILURE_RECOVERY_POSTCHECK", "3", "3", "3", "2", "2", "1", "1", "0",
    "4", "4", "0", "0", "8", "0", "2", "1", "1", "0", "0", "8", "1", "1", "1",
  ];
  requireCondition(
    parseDelimited(countFixture, "FAILURE_RECOVERY_POSTCHECK", 24).slice(1, 20).join("|")
      === "3|3|3|2|2|1|1|0|4|4|0|0|8|0|2|1|1|0|0"
      && countFixture.slice(20).join("|") === "8|1|1|1",
    "postcheck_count_fixture_failed",
  );

  const retryableStateFixture = [
    "AUTH_FAILURE_STATE", "1", "0", "1", "retryable_failure", "profile_suspended",
    "auth_temporarily_unavailable", "1", "0", "0",
  ];
  requireCondition(operationStateEquals(retryableStateFixture, {
    profileInactive: 1,
    banActive: 0,
    status: "retryable_failure",
    stage: "profile_suspended",
    errorCode: "auth_temporarily_unavailable",
    deactivatedEvents: 1,
    failureEvents: 0,
    successEvents: 0,
  }), "retryable_failure_audit_fixture_failed");

  const authUnconfirmedFixture = [
    "FINALIZATION_FAILURE_STATE", "1", "1", "1", "1", "0",
  ];
  requireCondition(
    authUnconfirmedFixture.slice(1).join("|") === "1|1|1|1|0",
    "auth_unconfirmed_processing_fixture_failed",
  );

  const secondAdminFixture = [
    "SECOND_ADMIN_RECOVERY_STATE", "1", "1", "1", "1", "1", "0", "1", "1",
  ];
  requireCondition(
    secondAdminFixture.slice(1).join("|") === "1|1|1|1|1|0|1|1",
    "second_admin_attempt_three_fixture_failed",
  );

  const snapshotFixture = [{
    operation_id: operation,
    target_profile_id: target,
    operation_code: "deactivate",
    status: "retryable_failure",
    completed_stage: "profile_suspended",
    attempt_count: 1,
    retryable: true,
    last_error_code: "auth_temporarily_unavailable",
    updated_at: confirmedAt,
  }];
  requireCondition(
    parseOperationSnapshot(snapshotFixture, { operationId: operation })?.attemptCount === 1,
    "operation_snapshot_fixture_failed",
  );
  const claimFixture = [{ ...snapshotFixture[0], status: "processing", retryable: false, last_error_code: null, claimed: true }];
  requireCondition(parseClaim(claimFixture, operation)?.claimed === true, "claim_fixture_failed");

  const authFixture = {
    id: target,
    email: "fixture@example.invalid",
    updated_at: confirmedAt,
    app_metadata: { sitaa_account_kind: "technical" },
    identities: [{ id: "fixture", provider: "email" }],
  };
  const fingerprintA = authFingerprint(authFixture);
  const fingerprintB = authFingerprint({ ...authFixture, email_confirmed_at: null });
  const fingerprintC = authFingerprint({ ...authFixture, updated_at: "2026-08-03T12:01:00.000Z" });
  requireCondition(fingerprintA === fingerprintB && fingerprintA !== fingerprintC, "auth_fingerprint_fixture_failed");
  const completedReplayBefore = ["OPERATION_SNAPSHOT", "4", "8", fingerprintA, fingerprintA];
  const completedReplayAfter = [...completedReplayBefore];
  const completedStartResult = {
    code: "account_deactivated",
    state: "completed",
    operationId: operation,
  };
  const completedRetryResult = { ...completedStartResult };
  assertSameSnapshot(completedReplayBefore, completedReplayAfter, "completed_replay_snapshot_fixture_failed");
  requireCondition(
    JSON.stringify(completedStartResult) === JSON.stringify(completedRetryResult)
      && authFingerprint(authFixture) === fingerprintA,
    "completed_replay_auth_fingerprint_fixture_failed",
  );

  const fakeRefreshClient = {
    auth: {
      refreshSession: async ({ refresh_token: refreshToken }) => ({
        error: null,
        data: {
          session: { access_token: "fixture-access", refresh_token: refreshToken },
          user: { id: adminA },
        },
      }),
    },
  };
  const refreshedFixture = await refreshExact(
    fakeRefreshClient,
    { refresh_token: "fixture-refresh" },
    adminA,
    "refresh_fixture_failed",
  );
  requireCondition(refreshedFixture.refresh_token === "fixture-refresh", "refresh_fixture_rejected");

  const normalBaselineFixture = [
    "FAILURE_RECOVERY_BASELINE",
    ...expectedBaselineChain(false).split("|"),
  ];
  const resumeBaselineFixture = [
    "FAILURE_RECOVERY_BASELINE",
    ...expectedBaselineChain(true).split("|"),
  ];
  requireCondition(
    baselineMatches(normalBaselineFixture, false)
      && baselineMatches(resumeBaselineFixture, true)
      && !baselineMatches(normalBaselineFixture, true),
    "resume_mode_baseline_fixture_failed",
  );

  const repairNeedsRestoreFixture = [
    "CONFIRMATION_REPAIR_BASELINE", "1", "1", "1", "1", "needs_restore",
  ];
  const repairAlreadyRestoredFixture = [
    "CONFIRMATION_REPAIR_BASELINE", "1", "1", "1", "1", "already_restored",
  ];
  const repairConflictFixture = [
    "CONFIRMATION_REPAIR_BASELINE", "1", "1", "1", "1", "conflict",
  ];
  const repairModeVerifiedFixture = [
    "TARGET_CONFIRMATION_RESTORED_CHECK", "1", "1",
  ];
  requireCondition(
    parseConfirmationRepairBaseline(repairNeedsRestoreFixture) === "needs_restore"
      && parseConfirmationRepairBaseline(repairAlreadyRestoredFixture) === "already_restored"
      && parseConfirmationRepairBaseline(repairConflictFixture) === "conflict"
      && parseDelimited(repairModeVerifiedFixture, "TARGET_CONFIRMATION_RESTORED_CHECK", 3)
        .slice(1).join("|") === "1|1",
    "restore_confirmation_only_mode_fixture_failed",
  );

  const capturedTimeline = capturedApprovalEvidenceLines(
    "2026-08-03T10:00:00.000Z",
    "2026-08-03T10:01:00.000Z",
    "2026-08-03T10:02:00.000Z",
  );
  requireCondition(
    capturedTimeline.join("|")
      === "BASELINE_APPROVED_UTC|2026-08-03T10:00:00.000Z|TARGET_CONTRACT_APPROVED_UTC|2026-08-03T10:01:00.000Z|MATRIX_IRREVERSIBLE_STARTED_UTC|2026-08-03T10:02:00.000Z"
      && !capturedApprovalEvidenceLines.toString().includes("utcNow"),
    "captured_approval_timestamps_fixture_failed",
  );

  requireCondition(
    assertSafeEvidenceLine("AUTH_FAILURE_INJECTION|RECORDED") === "AUTH_FAILURE_INJECTION|RECORDED"
      && assertSafeEvidenceLine("AUTH_REPEATED_AFTER_SYNCHRONIZED|false") === "AUTH_REPEATED_AFTER_SYNCHRONIZED|false",
    "evidence_fixture_failed",
  );
  requireCondition(HASH_PATTERN.test(CORE_EVIDENCE.sha256) && HASH_PATTERN.test(CORE_POSTCHECK_EVIDENCE.sha256), "central_hash_fixture_failed");
  console.log("B3A_HOSTED_AUTH_FAILURE_RECOVERY_FIXTURES|APPROVED");
}

function loadLocalContracts(repoRoot) {
  const reconciliationRoot = path.join(repoRoot, "supabase", "reconciliation");
  validateExactEvidence(reconciliationRoot, CORE_EVIDENCE);
  validateExactEvidence(reconciliationRoot, CORE_POSTCHECK_EVIDENCE);
  validateCanonicalEdge(repoRoot);
  const users = parseFixtureUsers(readRequiredText(
    path.join(reconciliationRoot, "b3a_matrix_hosted_auth_users.local.txt"),
    "fixture_users_missing",
  ));
  return { reconciliationRoot, adminA: users.get("admin_a"), adminB: users.get("admin_b") };
}

function expectedBaselineChain(resumeExistingTarget) {
  return resumeExistingTarget
    ? "3|3|3|2|2|2|2|0|0|4|0|1|1|1|0|0|1|6|6|2|1|0"
    : "2|2|2|2|2|2|2|0|0|4|0|0|0|0|0|0|0|6|6|2|1|0";
}

function baselineMatches(parts, resumeExistingTarget) {
  return Array.isArray(parts)
    && parts.length === 23
    && parts[0] === "FAILURE_RECOVERY_BASELINE"
    && parts.slice(1).join("|") === expectedBaselineChain(resumeExistingTarget);
}

function assertBaseline(parts, resumeExistingTarget) {
  const baseline = parseDelimited(parts, "FAILURE_RECOVERY_BASELINE", 23);
  requireCondition(
    baselineMatches(baseline, resumeExistingTarget),
    "failure_recovery_baseline_rejected",
  );
  console.log("FAILURE_RECOVERY_BASELINE|APPROVED");
}

function assertNoLocalRecoveryArtifacts(evidencePath, postcheckPath, repairPath) {
  requireCondition(
    !fs.existsSync(evidencePath) && !fs.existsSync(postcheckPath),
    "failure_recovery_evidence_already_exists",
  );
  requireCondition(!fs.existsSync(repairPath), "confirmation_repair_required");
}

async function restoreConfirmationOnlyMain() {
  const repoRoot = path.resolve(process.env.SITAA_B3A_REPO_ROOT ?? "");
  requireCondition(repoRoot.length > 0 && process.cwd() === repoRoot, "repository_root_required");
  requireCondition((process.env.SITAA_B3A_PROJECT_REF ?? "") === EXPECTED_PROJECT_REF, "project_ref_rejected");
  const repairPath = path.join(
    repoRoot,
    "supabase",
    "reconciliation",
    "b3a_matrix_hosted_auth_failure_recovery_confirmation_repair.local.txt",
  );
  const originalEmailConfirmedAt = readConfirmationRepairFile(repairPath);
  const databaseConnection = parsePostgresConnectionUri(process.env.SITAA_B3A_DB_URL ?? "");
  const repairState = parseConfirmationRepairBaseline(
    executeReadOnlySql(
      databaseConnection,
      confirmationRepairBaselineSql(originalEmailConfirmedAt),
      "CONFIRMATION_REPAIR_BASELINE",
    ),
  );
  requireCondition(repairState !== "conflict", "confirmation_repair_timestamp_conflict");
  let restoreOutcome = "already_restored";
  if (repairState === "needs_restore") {
    const restored = parseDelimited(
      executeConfirmationMutation(
        databaseConnection,
        restoreConfirmationFromRepairSql(originalEmailConfirmedAt),
        "TARGET_CONFIRMATION_RESTORED",
      ),
      "TARGET_CONFIRMATION_RESTORED",
      2,
    );
    requireCondition(
      restored[1] === "restored" || restored[1] === "already_restored",
      "confirmation_repair_mutation_rejected",
    );
    restoreOutcome = restored[1];
  }
  const verified = parseDelimited(
    executeReadOnlySql(
      databaseConnection,
      confirmationRepairVerifiedSql(originalEmailConfirmedAt),
      "TARGET_CONFIRMATION_RESTORED_CHECK",
    ),
    "TARGET_CONFIRMATION_RESTORED_CHECK",
    3,
  );
  requireCondition(verified.slice(1).join("|") === "1|1", "confirmation_repair_verification_rejected");
  console.log(`TARGET_CONFIRMATION_RESTORED|${restoreOutcome}`);
  removeRepairFileVerified(repairPath);
  console.log("CONFIRMATION_REPAIR_FILE|ABSENT");
  console.log("CONFIRMATION_REPAIR|APPROVED");
}

async function main({ readOnlyProbeOnly = false, resumeExistingTarget = false } = {}) {
  const repoRoot = path.resolve(process.env.SITAA_B3A_REPO_ROOT ?? "");
  requireCondition(repoRoot.length > 0 && process.cwd() === repoRoot, "repository_root_required");
  requireCondition((process.env.SITAA_B3A_PROJECT_REF ?? "") === EXPECTED_PROJECT_REF, "project_ref_rejected");
  const { reconciliationRoot, adminA, adminB } = loadLocalContracts(repoRoot);
  const evidencePath = path.join(reconciliationRoot, "b3a_matrix_hosted_auth_failure_recovery.local.txt");
  const postcheckPath = path.join(reconciliationRoot, "b3a_matrix_hosted_auth_failure_recovery_postcheck.local.txt");
  const repairPath = path.join(
    reconciliationRoot,
    "b3a_matrix_hosted_auth_failure_recovery_confirmation_repair.local.txt",
  );
  runtimeState.repairPath = repairPath;
  if (!readOnlyProbeOnly) {
    assertNoLocalRecoveryArtifacts(evidencePath, postcheckPath, repairPath);
  }
  const databaseConnection = parsePostgresConnectionUri(process.env.SITAA_B3A_DB_URL ?? "");
  runtimeState.databaseConnection = databaseConnection;
  const baselineParts = executeReadOnlySql(
    databaseConnection,
    baselineSql(adminA.id, adminB.id),
    "FAILURE_RECOVERY_BASELINE",
  );
  assertBaseline(baselineParts, resumeExistingTarget);
  const baselineApprovedUtc = utcNow();
  if (readOnlyProbeOnly) {
    console.log("READ_ONLY_TRANSACTION|true");
    console.log("ROLLBACK|true");
    runtimeState.databaseConnection = null;
    return;
  }

  if (!resumeExistingTarget) {
    console.log("Escribe CREATE_FAILURE_RECOVERY_TARGET para crear Target C.");
    if (!await readConfirmation("CREATE_FAILURE_RECOVERY_TARGET")) {
      console.log("FAILURE_RECOVERY_MATRIX|ABORTED");
      runtimeState.databaseConnection = null;
      process.exitCode = OPERATOR_ABORT_EXIT_CODE;
      return;
    }
  }

  assertNoLocalRecoveryArtifacts(evidencePath, postcheckPath, repairPath);
  const supabaseJsVersion = await loadSupabaseJs(repoRoot);
  let projectUrl = await readMasked("Project URL exacta: ");
  let publicKey = await readMasked("Publishable/anon key: ");
  let serviceKey = await readMasked("Service role/secret key: ");
  let adminAPassword = await readMasked("Contraseña de Admin A: ");
  let adminBPassword = await readMasked("Contraseña de Admin B: ");
  let targetPassword = await readMasked("Contraseña nueva de Target C: ");
  requireCondition(projectUrl === EXPECTED_PROJECT_URL, "project_url_rejected");
  requireCondition(
    publicKey.length > 0 && serviceKey.length > 0 && adminAPassword.length > 0
      && adminBPassword.length > 0 && targetPassword.length > 0,
    "credentials_required",
  );

  const adminAClient = createIsolatedClient(projectUrl, publicKey);
  const adminBClient = createIsolatedClient(projectUrl, publicKey);
  const targetClient = createIsolatedClient(projectUrl, publicKey);
  const serviceClient = createIsolatedClient(projectUrl, serviceKey);
  let adminASession = await signInExact(adminAClient, adminA.email, adminAPassword, adminA.id, "admin_a_login_failed");
  let adminBSession = await signInExact(adminBClient, adminB.email, adminBPassword, adminB.id, "admin_b_login_failed");

  runtimeState.phase = "target_creation";
  let targetEmail;
  let targetId;
  if (resumeExistingTarget) {
    const authUsers = await listAllAuthUsers(serviceClient);
    const targets = authUsers.filter((user) => isApprovedTargetEmail(user.email));
    requireCondition(targets.length === 1, "resume_target_inventory_rejected");
    targetId = targets[0].id;
    targetEmail = targets[0].email?.toLowerCase();
    requireCondition(
      UUID_PATTERN.test(targetId)
        && isApprovedTargetEmail(targetEmail)
        && targets[0].email_confirmed_at
        && !targets[0].banned_until
        && targets[0].app_metadata?.sitaa_account_kind === "technical"
        && targets[0].app_metadata?.sitaa_first_names === TARGET_FIRST_NAMES,
      "resume_target_auth_contract_rejected",
    );
  } else {
    assertNoLocalRecoveryArtifacts(evidencePath, postcheckPath, repairPath);
    targetEmail = generateTargetEmail();
    const created = await serviceClient.auth.admin.createUser({
      email: targetEmail,
      password: targetPassword,
      email_confirm: true,
      app_metadata: {
        sitaa_account_kind: "technical",
        sitaa_first_names: TARGET_FIRST_NAMES,
      },
    });
    requireCondition(!created.error && created.data?.user?.id, "failure_target_create_failed");
    targetId = created.data.user.id;
    requireCondition(
      UUID_PATTERN.test(targetId)
        && created.data.user.email?.toLowerCase() === targetEmail
        && created.data.user.email_confirmed_at
        && created.data.user.app_metadata?.sitaa_account_kind === "technical"
        && created.data.user.app_metadata?.sitaa_first_names === TARGET_FIRST_NAMES,
      "failure_target_auth_response_rejected",
    );
  }
  requireCondition(UUID_PATTERN.test(targetId) && isApprovedTargetEmail(targetEmail), "failure_target_identity_rejected");
  runtimeState.targetId = targetId;
  await signInExact(targetClient, targetEmail, targetPassword, targetId, "failure_target_login_failed");

  const targetContract = parseDelimited(
    executeReadOnlySql(databaseConnection, targetContractSql(targetId, targetEmail), "FAILURE_TARGET_CONTRACT"),
    "FAILURE_TARGET_CONTRACT",
    13,
  );
  requireCondition(
    targetContract.slice(1, 10).join("|") === "3|3|3|2|1|1|1|0|0"
      && targetContract[10].length > 0
      && HASH_PATTERN.test(targetContract[11])
      && HASH_PATTERN.test(targetContract[12]),
    "failure_target_contract_rejected",
  );
  const targetContractApprovedUtc = utcNow();
  const targetBaseline = {
    activatedAt: targetContract[10],
    identityHash: targetContract[11],
    assignmentHash: targetContract[12],
  };
  console.log(resumeExistingTarget
    ? "FAILURE_TARGET_RESUMED|APPROVED"
    : "FAILURE_TARGET_CREATED|APPROVED");
  console.log("FAILURE_TARGET_AUTH_CONTRACT|APPROVED");
  console.log("FAILURE_TARGET_ASSIGNMENTS|0");

  if (resumeExistingTarget) {
    console.log("Escribe RESUME_FAILURE_RECOVERY_TARGET para reutilizar Target C.");
    if (!await readConfirmation("RESUME_FAILURE_RECOVERY_TARGET")) {
      console.log("FAILURE_RECOVERY_MATRIX|ABORTED");
      runtimeState.databaseConnection = null;
      createSupabaseClient = null;
      process.exitCode = OPERATOR_ABORT_EXIT_CODE;
      return;
    }
  }

  runtimeState.phase = "before_second_confirmation";
  console.log("Escribe CONTINUE_FAILURE_RECOVERY_IRREVERSIBLE para iniciar operaciones B.3a.");
  if (!await readConfirmation("CONTINUE_FAILURE_RECOVERY_IRREVERSIBLE")) {
    console.log("FAILURE_RECOVERY_MATRIX|ABORTED");
    projectUrl = "";
    publicKey = "";
    serviceKey = "";
    adminAPassword = "";
    adminBPassword = "";
    targetPassword = "";
    runtimeState.databaseConnection = null;
    createSupabaseClient = null;
    process.exitCode = OPERATOR_ABORT_EXIT_CODE;
    return;
  }

  assertNoLocalRecoveryArtifacts(evidencePath, postcheckPath, repairPath);
  adminASession = await refreshExact(adminAClient, adminASession, adminA.id, "admin_a_pre_matrix_refresh_failed");
  adminBSession = await refreshExact(adminBClient, adminBSession, adminB.id, "admin_b_pre_matrix_refresh_failed");
  const irreversibleStartedUtc = utcNow();
  runtimeState.evidencePath = evidencePath;
  const evidence = [];
  const record = (line) => {
    assertSafeEvidenceLine(line);
    console.log(line);
    evidence.push(line);
    if (runtimeState.evidencePersisted) fs.appendFileSync(evidencePath, `${line}\n`, "utf8");
  };
  record(`HARNESS_VERSION|${HARNESS_VERSION}`);
  record(`NODE_RUNTIME|${process.version}`);
  record(`SUPABASE_JS_VERSION|${supabaseJsVersion}`);
  for (const line of capturedApprovalEvidenceLines(
    baselineApprovedUtc,
    targetContractApprovedUtc,
    irreversibleStartedUtc,
  )) record(line);
  record("FAILURE_RECOVERY_BASELINE|APPROVED");
  record(resumeExistingTarget
    ? "FAILURE_TARGET_RESUMED|APPROVED"
    : "FAILURE_TARGET_CREATED|APPROVED");
  record("FAILURE_TARGET_AUTH_CONTRACT|APPROVED");
  record("FAILURE_TARGET_ASSIGNMENTS|0");
  record("ADMIN_A_PRE_MATRIX_REFRESH|APPROVED");
  record("ADMIN_B_PRE_MATRIX_REFRESH|APPROVED");
  record("IRREVERSIBLE_CONFIRMATION|ACCEPTED");
  fs.writeFileSync(evidencePath, `${evidence.join("\n")}\n`, { encoding: "utf8", flag: "wx" });
  runtimeState.evidencePersisted = true;

  void adminASession;
  void adminBSession;
  const deactivationReason = "Prueba de fallo Auth reintentable B.3a";
  const deactivationRequestId = crypto.randomUUID();
  runtimeState.phase = "auth_failure_injection";
  const preparedDeactivation = await prepareOperation(
    adminAClient,
    targetId,
    "deactivate",
    deactivationReason,
    deactivationRequestId,
  );
  requireCondition(!preparedDeactivation.error && preparedDeactivation.operation, "deactivation_prepare_failed");
  requireCondition(
    preparedDeactivation.operation.status === "open"
      && preparedDeactivation.operation.completedStage === "profile_suspended"
      && preparedDeactivation.operation.attemptCount === 0,
    "deactivation_prepare_state_rejected",
  );
  const deactivationOperationId = preparedDeactivation.operation.operationId;
  const firstClaim = await claimOperation(serviceClient, deactivationOperationId, adminA.id);
  requireCondition(firstClaim.attemptCount === 1 && firstClaim.completedStage === "profile_suspended", "auth_failure_claim_rejected");
  const injectedFailure = await recordOperationResult(
    serviceClient,
    firstClaim,
    adminA.id,
    "retryable_failure",
    "auth_temporarily_unavailable",
  );
  requireCondition(
    injectedFailure.status === "retryable_failure"
      && injectedFailure.completedStage === "profile_suspended"
      && injectedFailure.attemptCount === 1
      && injectedFailure.lastErrorCode === "auth_temporarily_unavailable",
    "auth_failure_injection_rejected",
  );
  const failureState = parseDelimited(
    executeReadOnlySql(databaseConnection, authFailureStateSql(targetId, deactivationOperationId, 1, "AUTH_FAILURE_STATE"), "AUTH_FAILURE_STATE"),
    "AUTH_FAILURE_STATE",
    10,
  );
  requireCondition(operationStateEquals(failureState, {
    profileInactive: 1,
    banActive: 0,
    status: "retryable_failure",
    stage: "profile_suspended",
    errorCode: "auth_temporarily_unavailable",
    deactivatedEvents: 1,
    failureEvents: 0,
    successEvents: 0,
  }), "auth_failure_database_state_rejected");
  record("AUTH_FAILURE_INJECTION|RECORDED");
  record("AUTH_FAILURE_STAGE|profile_suspended");
  record("AUTH_FAILURE_ATTEMPT|1");
  record("PROFILE_EVENT_COUNT|1");
  record(`AUTH_FAILURE_INJECTED_UTC|${utcNow()}`);

  runtimeState.phase = "request_replays";
  const replayBefore = parseDelimited(
    executeReadOnlySql(databaseConnection, operationSnapshotSql(targetId), "OPERATION_SNAPSHOT"),
    "OPERATION_SNAPSHOT",
    5,
  );
  const sameReplay = await prepareOperation(adminAClient, targetId, "deactivate", `  ${deactivationReason}  `, deactivationRequestId);
  requireCondition(
    !sameReplay.error
      && sameReplay.operation?.operationId === deactivationOperationId
      && sameReplay.operation.status === "retryable_failure",
    "same_payload_replay_rejected",
  );
  const replayAfter = parseDelimited(
    executeReadOnlySql(databaseConnection, operationSnapshotSql(targetId), "OPERATION_SNAPSHOT"),
    "OPERATION_SNAPSHOT",
    5,
  );
  assertSameSnapshot(replayBefore, replayAfter, "same_payload_replay_mutated_state");
  record("PREPARE_REQUEST_ID_SAME_PAYLOAD_REPLAY|APPROVED");

  const conflictBefore = replayAfter;
  const conflict = await prepareOperation(adminAClient, targetId, "deactivate", `${deactivationReason} distinto`, deactivationRequestId);
  requireCondition(
    databaseErrorMatches(conflict.error, "23505", "sitaa_auth_operation_request_id_conflict"),
    "request_id_payload_conflict_rejected",
  );
  const conflictAfter = parseDelimited(
    executeReadOnlySql(databaseConnection, operationSnapshotSql(targetId), "OPERATION_SNAPSHOT"),
    "OPERATION_SNAPSHOT",
    5,
  );
  assertSameSnapshot(conflictBefore, conflictAfter, "request_id_conflict_mutated_state");
  record("PREPARE_REQUEST_ID_PAYLOAD_CONFLICT|APPROVED");

  const busy = await prepareOperation(
    adminAClient,
    targetId,
    "reactivate",
    "Nueva solicitud contra operación no final B.3a",
    crypto.randomUUID(),
  );
  requireCondition(
    databaseErrorMatches(busy.error, "55000", "sitaa_auth_operation_target_busy"),
    "nonfinal_busy_contract_rejected",
  );
  const busyAfter = parseDelimited(
    executeReadOnlySql(databaseConnection, operationSnapshotSql(targetId), "OPERATION_SNAPSHOT"),
    "OPERATION_SNAPSHOT",
    5,
  );
  assertSameSnapshot(conflictAfter, busyAfter, "nonfinal_busy_mutated_state");
  record("PREPARE_TARGET_NONFINAL_BUSY|APPROVED");

  runtimeState.phase = "auth_failure_recovery";
  const recoveredEdge = await edgeResponse(adminAClient, buildRetryPayload(deactivationOperationId));
  requireCondition(
    !recoveredEdge.hadTransportError
      && recoveredEdge.data.operationId === deactivationOperationId
      && recoveredEdge.data.state === "completed"
      && recoveredEdge.data.code === "account_deactivated",
    "auth_failure_edge_recovery_rejected",
  );
  const recoveredState = parseDelimited(
    executeReadOnlySql(databaseConnection, authFailureStateSql(targetId, deactivationOperationId, 2, "AUTH_FAILURE_RECOVERED"), "AUTH_FAILURE_RECOVERED"),
    "AUTH_FAILURE_RECOVERED",
    10,
  );
  requireCondition(operationStateEquals(recoveredState, {
    profileInactive: 1,
    banActive: 1,
    status: "succeeded",
    stage: "completed",
    errorCode: "",
    deactivatedEvents: 1,
    failureEvents: 0,
    successEvents: 1,
  }), "auth_failure_recovery_state_rejected");
  record("AUTH_FAILURE_RECOVERY|COMPLETED");
  record("RETRY_IDEMPOTENCY|APPROVED");
  record("PROFILE_EVENT_COUNT_AFTER_RETRY|1");
  record("RETRYABLE_FAILURE_AUDIT_EVENTS|0");
  record("AUTH_SUCCESS_EVENT_COUNT|1");
  record(`AUTH_FAILURE_RECOVERED_UTC|${utcNow()}`);

  const completedBefore = parseDelimited(
    executeReadOnlySql(databaseConnection, operationSnapshotSql(targetId), "OPERATION_SNAPSHOT"),
    "OPERATION_SNAPSHOT",
    5,
  );
  const completedAuthBefore = authFingerprint(await exactAdminUser(serviceClient, targetId));
  const completedStartReplay = await edgeResponse(
    adminAClient,
    buildStartPayload(targetId, "deactivate", deactivationReason, deactivationRequestId),
  );
  requireCondition(
    !completedStartReplay.hadTransportError
      && completedStartReplay.data.operationId === deactivationOperationId
      && completedStartReplay.data.state === "completed"
      && completedStartReplay.data.code === "account_deactivated",
    "completed_start_replay_rejected",
  );
  const completedRetryReplay = await edgeResponse(
    adminAClient,
    buildRetryPayload(deactivationOperationId),
  );
  requireCondition(
    !completedRetryReplay.hadTransportError
      && completedRetryReplay.data.operationId === deactivationOperationId
      && completedRetryReplay.data.state === "completed"
      && completedRetryReplay.data.code === "account_deactivated",
    "completed_retry_replay_rejected",
  );
  const completedAfter = parseDelimited(
    executeReadOnlySql(databaseConnection, operationSnapshotSql(targetId), "OPERATION_SNAPSHOT"),
    "OPERATION_SNAPSHOT",
    5,
  );
  const completedAuthAfter = authFingerprint(await exactAdminUser(serviceClient, targetId));
  assertSameSnapshot(completedBefore, completedAfter, "completed_replays_mutated_state");
  requireCondition(completedAuthAfter === completedAuthBefore, "completed_replays_repeated_auth");
  record("COMPLETED_START_REPLAY|APPROVED");
  record("COMPLETED_RETRY_REPLAY|APPROVED");
  record("AUTH_REPEATED_DURING_COMPLETED_REPLAYS|false");

  runtimeState.phase = "reactivation_auth_sync";
  const reactivationReason = "Prueba de recuperación por segundo administrador B.3a";
  const preparedReactivation = await prepareOperation(
    adminAClient,
    targetId,
    "reactivate",
    reactivationReason,
    crypto.randomUUID(),
  );
  requireCondition(!preparedReactivation.error && preparedReactivation.operation, "reactivation_prepare_failed");
  requireCondition(
    preparedReactivation.operation.status === "open"
      && preparedReactivation.operation.completedStage === "prepared"
      && preparedReactivation.operation.attemptCount === 0,
    "reactivation_prepare_state_rejected",
  );
  const reactivationOperationId = preparedReactivation.operation.operationId;
  const reactivationClaim = await claimOperation(serviceClient, reactivationOperationId, adminA.id);
  requireCondition(
    reactivationClaim.attemptCount === 1 && reactivationClaim.completedStage === "prepared",
    "reactivation_claim_rejected",
  );
  let reactivationAuthCalls = 0;
  const authRestored = await serviceClient.auth.admin.updateUserById(targetId, { ban_duration: "none" });
  reactivationAuthCalls += 1;
  requireCondition(!authRestored.error && authRestored.data?.user?.id === targetId, "reactivation_auth_update_failed");
  const synchronizedOperation = await recordOperationResult(
    serviceClient,
    reactivationClaim,
    adminA.id,
    "auth_succeeded",
    null,
  );
  requireCondition(
    synchronizedOperation.status === "processing"
      && synchronizedOperation.completedStage === "auth_synchronized"
      && synchronizedOperation.attemptCount === 1,
    "reactivation_auth_sync_rejected",
  );
  const synchronizedState = parseDelimited(
    executeReadOnlySql(databaseConnection, reactivationSynchronizedSql(targetId, reactivationOperationId, adminA.id), "REACTIVATION_SYNCHRONIZED"),
    "REACTIVATION_SYNCHRONIZED",
    7,
  );
  requireCondition(
    synchronizedState[1] === "1" && synchronizedState[2] === "1"
      && synchronizedState[3] === "1" && synchronizedState[4].length > 0
      && synchronizedState[5] === "1" && synchronizedState[6] === "0",
    "reactivation_synchronized_database_state_rejected",
  );
  const authSynchronizedAt = synchronizedState[4];
  const targetAuthBeforeInjection = await exactAdminUser(serviceClient, targetId);
  const originalEmailConfirmedAt = targetAuthBeforeInjection.email_confirmed_at;
  requireCondition(
    typeof originalEmailConfirmedAt === "string" && Number.isFinite(Date.parse(originalEmailConfirmedAt)),
    "target_confirmation_missing",
  );
  const synchronizedAuthFingerprint = authFingerprint(targetAuthBeforeInjection);
  record(`REACTIVATION_AUTH_SYNCHRONIZED_UTC|${utcNow()}`);

  runtimeState.phase = "finalization_failure_injection";
  adminASession = await refreshExact(
    adminAClient,
    adminASession,
    adminA.id,
    "admin_a_pre_finalization_failure_refresh_failed",
  );
  writeConfirmationRepairFile(repairPath, originalEmailConfirmedAt);
  runtimeState.originalEmailConfirmedAt = originalEmailConfirmedAt;
  runtimeState.repairPath = repairPath;
  runtimeState.confirmationNeedsRestoration = true;
  const cleared = parseDelimited(
    executeConfirmationMutation(
      databaseConnection,
      clearConfirmationSql(targetId, originalEmailConfirmedAt),
      "TARGET_CONFIRMATION_CLEARED",
    ),
    "TARGET_CONFIRMATION_CLEARED",
    2,
  );
  requireCondition(cleared[1] === "true", "confirmation_clear_rejected");
  let finalizationEdge;
  let confirmationRestoreOutcome;
  try {
    finalizationEdge = await edgeResponse(adminAClient, buildRetryPayload(reactivationOperationId));
    requireCondition(
      finalizationEdge.hadTransportError
        && finalizationEdge.httpStatus === 409
        && finalizationEdge.data.operationId === reactivationOperationId
        && finalizationEdge.data.state === "pending"
        && finalizationEdge.data.code === "auth_unconfirmed",
      "finalization_failure_edge_contract_rejected",
    );
    const finalizationState = parseDelimited(
      executeReadOnlySql(
        databaseConnection,
        finalizationFailureSql(targetId, reactivationOperationId, authSynchronizedAt),
        "FINALIZATION_FAILURE_STATE",
      ),
      "FINALIZATION_FAILURE_STATE",
      6,
    );
    requireCondition(
      finalizationState.slice(1).join("|") === "1|1|1|1|0",
      "finalization_failure_database_state_rejected",
    );
    const targetAuthAfterFailedFinalize = await exactAdminUser(serviceClient, targetId);
    requireCondition(
      authFingerprint(targetAuthAfterFailedFinalize) === synchronizedAuthFingerprint,
      "auth_repeated_after_synchronized",
    );
    record("FINALIZATION_FAILURE_INJECTION|RECORDED");
    record("FINALIZATION_FAILURE_CODE|auth_unconfirmed");
    record("FINALIZATION_OPERATION_STATUS|processing");
    record("FINALIZATION_OPERATION_ATTEMPT|2");
    record("AUTH_REPEATED_AFTER_SYNCHRONIZED|false");
    record(`FINALIZATION_FAILURE_INJECTED_UTC|${utcNow()}`);
  } finally {
    runtimeState.phase = "confirmation_restoration";
    confirmationRestoreOutcome = await restoreConfirmationIfNeeded();
  }
  const restoredConfirmationUser = await exactAdminUser(serviceClient, targetId);
  requireCondition(
    restoredConfirmationUser.email_confirmed_at === originalEmailConfirmedAt
      && authFingerprint(restoredConfirmationUser) === synchronizedAuthFingerprint,
    "target_confirmation_restoration_rejected",
  );
  requireCondition(
    confirmationRestoreOutcome === "restored" || confirmationRestoreOutcome === "already_restored",
    "confirmation_restore_outcome_rejected",
  );
  record(`TARGET_CONFIRMATION_RESTORED|${confirmationRestoreOutcome}`);

  runtimeState.phase = "second_admin_recovery";
  adminBSession = await refreshExact(
    adminBClient,
    adminBSession,
    adminB.id,
    "admin_b_pre_second_recovery_refresh_failed",
  );
  const secondAdminEdge = await edgeResponse(adminBClient, buildRetryPayload(reactivationOperationId));
  requireCondition(
    !secondAdminEdge.hadTransportError
      && secondAdminEdge.data.operationId === reactivationOperationId
      && secondAdminEdge.data.state === "completed"
      && secondAdminEdge.data.code === "account_reactivated",
    "second_admin_recovery_edge_rejected",
  );
  const finalAuthUser = await exactAdminUser(serviceClient, targetId);
  requireCondition(
    authFingerprint(finalAuthUser) === synchronizedAuthFingerprint,
    "auth_repeated_during_recovery",
  );
  const secondAdminState = parseDelimited(
    executeReadOnlySql(
      databaseConnection,
      secondAdminRecoverySql(
        targetId,
        reactivationOperationId,
        adminA.id,
        adminB.id,
        targetBaseline.activatedAt,
        targetBaseline.identityHash,
        targetBaseline.assignmentHash,
      ),
      "SECOND_ADMIN_RECOVERY_STATE",
    ),
    "SECOND_ADMIN_RECOVERY_STATE",
    9,
  );
  requireCondition(secondAdminState.slice(1).join("|") === "1|1|1|1|1|0|1|1", "second_admin_recovery_state_rejected");
  requireCondition(reactivationAuthCalls === 1, "reactivation_auth_call_count_rejected");
  record("SECOND_ADMIN_RECOVERY|APPROVED");
  record("AUTH_CALLS_FOR_REACTIVATION|1");
  record("AUTH_REPEATED_DURING_RECOVERY|false");
  record("ACTIVATED_AT_PRESERVED|true");
  record("AUTH_IDENTITY_PRESERVED|true");
  record(`SECOND_ADMIN_RECOVERY_COMPLETED_UTC|${utcNow()}`);

  runtimeState.phase = "final_postcheck";
  const finalPostcheck = parseDelimited(
    executeReadOnlySql(
      databaseConnection,
      finalPostcheckSql(targetId, adminA.id, adminB.id, originalEmailConfirmedAt),
      "FAILURE_RECOVERY_POSTCHECK",
    ),
    "FAILURE_RECOVERY_POSTCHECK",
    24,
  );
  requireCondition(
    finalPostcheck.slice(1, 20).join("|") === "3|3|3|2|2|1|1|0|4|4|0|0|8|0|2|1|1|0|0"
      && finalPostcheck.slice(20).join("|") === "8|1|1|1"
      && !fs.existsSync(repairPath),
    "failure_recovery_postcheck_rejected",
  );
  const completedUtc = utcNow();
  const postcheckLines = [
    "FAILURE_RECOVERY_POSTCHECK|APPROVED",
    "READ_ONLY_TRANSACTION|true",
    "ROLLBACK|true",
    "AUTH_USERS|3",
    "AUTH_IDENTITIES|3",
    "PROFILES|3",
    "ROLE_ASSIGNMENTS|2",
    "B1_ACTIVE_AUTHORITY|2/2",
    "TARGET_ACTIVE|true",
    "TARGET_AUTH_BAN_ACTIVE|false",
    "TARGET_ASSIGNMENTS|0",
    "B3A_OPERATIONS|4",
    "B3A_SUCCEEDED_OPERATIONS|4",
    "B3A_NONFINAL_OPERATIONS|0",
    "B3A_NONSUCCEEDED_OPERATIONS|0",
    "EXPECTED_ADMIN_EVENTS|8",
    "AUTH_FAILURE_EVENTS|0",
    "NEW_AUTH_SUCCESS_EVENTS|2",
    "TARGET_EMAIL_CONFIRMED|true",
    "CONFIRMATION_REPAIR_FILE|ABSENT",
    `MATRIX_COMPLETED_UTC|${completedUtc}`,
    "FAILURE_RECOVERY_MATRIX|APPROVED",
  ];
  for (const line of postcheckLines) assertSafeEvidenceLine(line);
  fs.writeFileSync(postcheckPath, `${postcheckLines.join("\n")}\n`, { encoding: "utf8", flag: "wx" });
  record(`MATRIX_COMPLETED_UTC|${completedUtc}`);
  record("FAILURE_RECOVERY_POSTCHECK|APPROVED");
  record("TARGET_EMAIL_CONFIRMED|true");
  record("CONFIRMATION_REPAIR_FILE|ABSENT");
  record("READ_ONLY_TRANSACTION|true");
  record("ROLLBACK|true");
  record("FAILURE_RECOVERY_MATRIX|APPROVED");

  projectUrl = "";
  publicKey = "";
  serviceKey = "";
  adminAPassword = "";
  adminBPassword = "";
  targetPassword = "";
  runtimeState.databaseConnection = null;
  createSupabaseClient = null;
}

function appendFailureEvidence(line) {
  assertSafeEvidenceLine(line);
  console.error(line);
  if (runtimeState.evidencePersisted && runtimeState.evidencePath && fs.existsSync(runtimeState.evidencePath)) {
    fs.appendFileSync(runtimeState.evidencePath, `${line}\n`, "utf8");
  }
}

async function handleFailure(error) {
  const code = error instanceof SafeFailure ? error.code : "unexpected_failure";
  let safeCode = /^[a-z][a-z0-9_]{0,79}$/.test(code) && !containsForbiddenEvidence(code)
    ? code
    : "unexpected_failure";
  if (runtimeState.confirmationNeedsRestoration) {
    try {
      const restoreOutcome = await restoreConfirmationIfNeeded();
      appendFailureEvidence(`TARGET_CONFIRMATION_RESTORED|${restoreOutcome}`);
    } catch {
      if (runtimeState.confirmationRestoredVerified) {
        appendFailureEvidence(`TARGET_CONFIRMATION_RESTORED|${runtimeState.confirmationRestoreOutcome}`);
        appendFailureEvidence("CONFIRMATION_REPAIR_FILE|PRESENT");
        safeCode = "confirmation_repair_file_cleanup_required";
      } else {
        appendFailureEvidence("TARGET_CONFIRMATION_RESTORED|false");
      }
    }
  } else if (
    runtimeState.confirmationRestoredVerified
      && runtimeState.repairPath
      && fs.existsSync(runtimeState.repairPath)
  ) {
    appendFailureEvidence(`TARGET_CONFIRMATION_RESTORED|${runtimeState.confirmationRestoreOutcome}`);
    appendFailureEvidence("CONFIRMATION_REPAIR_FILE|PRESENT");
    safeCode = "confirmation_repair_file_cleanup_required";
  }
  appendFailureEvidence(`FAILURE_RECOVERY_MATRIX|REJECTED|${safeCode}`);
  if (runtimeState.evidencePersisted && runtimeState.databaseConnection && runtimeState.targetId) {
    const phase = FAILURE_PHASES.has(runtimeState.phase) ? runtimeState.phase : "auth_failure_injection";
    appendFailureEvidence(`FAILURE_PHASE|${phase}`);
    appendFailureEvidence(`DIAGNOSTIC_CONFIRMATION_REPAIR_FILE|${
      runtimeState.repairPath && fs.existsSync(runtimeState.repairPath) ? "PRESENT" : "ABSENT"
    }`);
    try {
      const diagnostic = parseDelimited(
        executeReadOnlySql(
          runtimeState.databaseConnection,
          failureDiagnosticSql(runtimeState.targetId),
          "FAILURE_RECOVERY_DIAGNOSTIC",
        ),
        "FAILURE_RECOVERY_DIAGNOSTIC",
        14,
      );
      requireCondition(new Set(["active", "inactive", "missing"]).has(diagnostic[1]), "failure_diagnostic_profile_state_invalid");
      requireCondition(diagnostic.slice(2).every((value) => /^(0|[1-9]\d*)$/.test(value)), "failure_diagnostic_count_invalid");
      appendFailureEvidence("FAILURE_DIAGNOSTIC|APPROVED");
      appendFailureEvidence(`DIAGNOSTIC_PROFILE_STATE|${diagnostic[1]}`);
      appendFailureEvidence(`DIAGNOSTIC_AUTH_BAN_ACTIVE|${diagnostic[2]}`);
      appendFailureEvidence(`DIAGNOSTIC_TARGET_OPERATIONS|${diagnostic[3]}`);
      appendFailureEvidence(`DIAGNOSTIC_OPEN_OPERATIONS|${diagnostic[4]}`);
      appendFailureEvidence(`DIAGNOSTIC_PROCESSING_OPERATIONS|${diagnostic[5]}`);
      appendFailureEvidence(`DIAGNOSTIC_RETRYABLE_OPERATIONS|${diagnostic[6]}`);
      appendFailureEvidence(`DIAGNOSTIC_SUCCEEDED_OPERATIONS|${diagnostic[7]}`);
      appendFailureEvidence(`DIAGNOSTIC_TERMINAL_OPERATIONS|${diagnostic[8]}`);
      appendFailureEvidence(`DIAGNOSTIC_PROFILE_SUSPENDED_STAGE|${diagnostic[9]}`);
      appendFailureEvidence(`DIAGNOSTIC_AUTH_SYNCHRONIZED_STAGE|${diagnostic[10]}`);
      appendFailureEvidence(`DIAGNOSTIC_COMPLETED_STAGE|${diagnostic[11]}`);
      appendFailureEvidence(`DIAGNOSTIC_TARGET_ADMIN_EVENTS|${diagnostic[12]}`);
      appendFailureEvidence(`DIAGNOSTIC_TARGET_EMAIL_CONFIRMED|${diagnostic[13]}`);
      appendFailureEvidence("DIAGNOSTIC_READ_ONLY_ROLLBACK|true");
    } catch {
      appendFailureEvidence("FAILURE_DIAGNOSTIC|UNAVAILABLE");
    }
  }
  runtimeState.databaseConnection = null;
  createSupabaseClient = null;
  process.exitCode = 1;
}

const repoRoot = path.resolve(process.env.SITAA_B3A_REPO_ROOT ?? "");
try {
  if (process.argv.includes("--self-test")) {
    requireCondition(repoRoot.length > 0, "repository_root_required");
    await runSelfTests(repoRoot);
  } else if (process.argv.includes("--restore-confirmation-only")) {
    await restoreConfirmationOnlyMain();
  } else if (process.argv.includes("--read-only-probe")) {
    await main({ readOnlyProbeOnly: true });
  } else if (process.argv.includes("--resume-existing-target")) {
    await main({ resumeExistingTarget: true });
  } else {
    await main();
  }
} catch (error) {
  if (process.argv.includes("--self-test")) {
    console.error("B3A_HOSTED_AUTH_FAILURE_RECOVERY_FIXTURES|REJECTED");
    process.exitCode = 1;
  } else if (process.argv.includes("--restore-confirmation-only")) {
    const code = error instanceof SafeFailure ? error.code : "unexpected_failure";
    const safeCode = /^[a-z][a-z0-9_]{0,79}$/.test(code) && !containsForbiddenEvidence(code)
      ? code
      : "unexpected_failure";
    console.error(`CONFIRMATION_REPAIR|REJECTED|${safeCode}`);
    process.exitCode = 1;
  } else {
    await handleFailure(error);
  }
}
'@

function Assert-TemporaryPath {
  param([Parameter(Mandatory = $true)][string]$Candidate)

  $rootWithSeparator = $repoRoot.TrimEnd(
    [System.IO.Path]::DirectorySeparatorChar,
    [System.IO.Path]::AltDirectorySeparatorChar
  ) + [System.IO.Path]::DirectorySeparatorChar
  if (-not $Candidate.StartsWith(
      $rootWithSeparator,
      [System.StringComparison]::OrdinalIgnoreCase
    )) {
    throw "La ruta temporal quedó fuera de la raíz del repositorio."
  }
}

function Assert-ScriptEncoding {
  $bytes = [System.IO.File]::ReadAllBytes($PSCommandPath)
  if (
    $bytes.Length -lt 3 -or
    $bytes[0] -ne 0xEF -or
    $bytes[1] -ne 0xBB -or
    $bytes[2] -ne 0xBF
  ) {
    throw "El arnés debe estar guardado como UTF-8 con BOM."
  }
  $legacyText = Get-Content -Raw -LiteralPath $PSCommandPath
  foreach ($literal in @(
      "Contraseña",
      "recuperación",
      "técnico",
      "confirmación"
    )) {
    if (-not $legacyText.Contains($literal)) {
      throw "La validación UTF-8 de Windows PowerShell rechazó el arnés."
    }
  }
  if (
    $legacyText.Contains([char]0x00C3) -or
    $legacyText.Contains([char]0x00C2) -or
    $legacyText.Contains([char]0x00E2) -or
    $legacyText.Contains([char]0xFFFD)
  ) {
    throw "Se detectó mojibake en el arnés."
  }
  if (
    [System.Text.RegularExpressions.Regex]::IsMatch($legacyText, '(?<!\r)\n') -or
    [System.Text.RegularExpressions.Regex]::IsMatch($legacyText, '\r(?!\n)')
  ) {
    throw "El arnés debe conservar finales de línea CRLF."
  }
}

function Get-EvidenceFingerprint {
  param([Parameter(Mandatory = $true)][string]$Path)

  if (-not (Test-Path -LiteralPath $Path)) {
    return "ABSENT"
  }
  $item = Get-Item -LiteralPath $Path
  $hash = (Get-FileHash -Algorithm SHA256 -LiteralPath $Path).Hash
  return ($item.Length.ToString() + ":" + $hash)
}

try {
  if ($currentRoot -ne $repoRoot) {
    throw "Ejecuta el arnés desde la raíz del repositorio."
  }
  $modeCount = 0
  foreach ($mode in @(
      $ValidateOnly,
      $ReadOnlyProbeOnly,
      $ResumeExistingTarget,
      $RestoreConfirmationOnly
    )) {
    if ($mode) {
      $modeCount++
    }
  }
  if ($modeCount -gt 1) {
    throw "Los modos del arnés son mutuamente excluyentes."
  }
  Assert-ScriptEncoding
  Assert-TemporaryPath -Candidate $temporaryRoot
  $evidenceRoot = Join-Path $repoRoot "supabase\reconciliation"
  $evidenceBefore = @{}
  foreach ($name in $protectedLocalArtifactNames) {
    $evidenceBefore[$name] = Get-EvidenceFingerprint -Path (Join-Path $evidenceRoot $name)
  }

  [System.IO.Directory]::CreateDirectory($temporaryRoot) | Out-Null
  try {
    [System.IO.File]::SetAttributes(
      $temporaryRoot,
      [System.IO.FileAttributes]::Directory -bor [System.IO.FileAttributes]::Hidden
    )
  }
  catch {
    # El prefijo con punto mantiene el directorio oculto fuera de Windows.
  }
  [System.IO.File]::WriteAllText(
    $nodeModulePath,
    $nodeModule,
    [System.Text.UTF8Encoding]::new($false)
  )
  $env:SITAA_B3A_REPO_ROOT = $repoRoot

  if ($ValidateOnly) {
    & node --check $nodeModulePath
    if ($LASTEXITCODE -ne 0) {
      throw "La validación sintáctica del módulo Node falló."
    }
    & node $nodeModulePath --self-test
    if ($LASTEXITCODE -ne 0) {
      throw "Las fixtures locales del módulo Node fallaron."
    }
    foreach ($name in $protectedLocalArtifactNames) {
      $after = Get-EvidenceFingerprint -Path (Join-Path $evidenceRoot $name)
      if ($after -ne $evidenceBefore[$name]) {
        throw "ValidateOnly modificó evidencia."
      }
    }
    Write-Output "B3A_HOSTED_AUTH_FAILURE_RECOVERY_STATIC_VALIDATION|APPROVED"
    return
  }

  if (-not (Test-Path -LiteralPath (Join-Path $repoRoot "package.json"))) {
    throw "No se reconoció la raíz del repositorio."
  }
  if ([string]::IsNullOrWhiteSpace($env:SITAA_B3A_PROJECT_REF)) {
    throw "Falta SITAA_B3A_PROJECT_REF."
  }
  if ([string]::IsNullOrWhiteSpace($env:SITAA_B3A_DB_URL)) {
    throw "Falta SITAA_B3A_DB_URL."
  }

  if ($RestoreConfirmationOnly) {
    & node $nodeModulePath --restore-confirmation-only
  }
  elseif ($ReadOnlyProbeOnly) {
    & node $nodeModulePath --read-only-probe
  }
  elseif ($ResumeExistingTarget) {
    & node $nodeModulePath --resume-existing-target
  }
  else {
    & node $nodeModulePath
  }
  $nodeExitCode = $LASTEXITCODE
  if ($nodeExitCode -eq 2) {
    exit 2
  }
  if ($nodeExitCode -ne 0) {
    throw "El arnés terminó sin aprobación."
  }
  if ($ReadOnlyProbeOnly) {
    foreach ($name in $protectedLocalArtifactNames) {
      $after = Get-EvidenceFingerprint -Path (Join-Path $evidenceRoot $name)
      if ($after -ne $evidenceBefore[$name]) {
        throw "ReadOnlyProbeOnly modificó evidencia."
      }
    }
  }
}
finally {
  Remove-Item Env:SITAA_B3A_REPO_ROOT -ErrorAction SilentlyContinue
  Remove-Item Env:SITAA_B3A_PROJECT_REF -ErrorAction SilentlyContinue
  Remove-Item Env:SITAA_B3A_DB_URL -ErrorAction SilentlyContinue
  if (Test-Path -LiteralPath $temporaryRoot) {
    Assert-TemporaryPath -Candidate $temporaryRoot
    Remove-Item -LiteralPath $temporaryRoot -Recurse -Force
  }
  $nodeModule = $null
}
