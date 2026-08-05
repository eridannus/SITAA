param(
  [switch]$ValidateOnly,
  [switch]$ReadOnlyProbeOnly,
  [switch]$ResumeProvisioning,
  [switch]$RestoreHandlerOnly,
  [switch]$AbandonProvisioning,
  [switch]$FinalizeProvisioningOnly
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$scriptRoot = Split-Path -Parent $PSCommandPath
$repoRoot = [System.IO.Path]::GetFullPath((Join-Path $scriptRoot ".."))
$currentRoot = [System.IO.Path]::GetFullPath((Get-Location).Path)
$temporaryRoot = [System.IO.Path]::GetFullPath(
  (Join-Path $repoRoot (".sitaa-b3a-target-bootstrap-runtime-" + [guid]::NewGuid().ToString("N")))
)
$nodeModulePath = Join-Path $temporaryRoot "failure-target-bootstrap.mjs"
$protectedLocalArtifactNames = @(
  "b3a_matrix_failure_recovery_target_bootstrap.local.txt",
  "b3a_matrix_failure_recovery_target_bootstrap.next.local.txt",
  "b3a_matrix_failure_recovery_target_bootstrap_postcheck.local.txt",
  "b3a_matrix_failure_recovery_target_bootstrap_postcheck.next.local.txt",
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
import { spawnSync } from "node:child_process";

const CURRENT_BOOTSTRAP_VERSION = "2026-08-04-b3a-failure-target-bootstrap-v7";
const RECOVERABLE_PREDECESSOR_VERSION = "2026-08-04-b3a-failure-target-bootstrap-v6";
const VERSION = CURRENT_BOOTSTRAP_VERSION;
const RECOVERABLE_REPAIR_OPTIONS = Object.freeze({ allowRecoverablePredecessor: true });
const EXPECTED_PROJECT_REF = "upttfqjogltvymnaubkg";
const EXPECTED_PROJECT_URL = `https://${EXPECTED_PROJECT_REF}.supabase.co`;
const EXPECTED_SUPABASE_JS_VERSION = "2.110.1";
const LOCAL_JSON_GITIGNORE_RULE = "supabase/reconciliation/*.local.json";
const EXPECTED_HANDLER_MD5 = "156398fbb0da020e2b8b57db92b87fcd";
const EXPECTED_HANDLER_ACL = "{postgres=X/postgres,service_role=X/postgres}";
const HANDLER_SIGNATURE = "public.handle_sitaa_auth_user_created()";
const TARGET_FIRST_NAMES = "Objetivo Matriz C";
const TARGET_EMAIL_SQL_PATTERN = "^b3a-failure-target-[0-9]{17}-[0-9a-f]{12}@example\\.invalid$";
const TARGET_EMAIL_PATTERN = /^b3a-failure-target-\d{17}-[a-f0-9]{12}@example\.invalid$/;
const UUID_PATTERN = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const MD5_PATTERN = /^[0-9a-f]{32}$/;
const SHA256_PATTERN = /^[0-9a-f]{64}$/;
const REPAIR_KEYS = Object.freeze([
  "version",
  "target_email",
  "target_uuid",
  "original_oid",
  "original_acl_base64",
  "original_md5",
  "snapshot_sha256",
  "snapshot_relative_path",
  "phase",
]);
const REPAIR_PHASES = new Set([
  "handler_captured",
  "handler_gate_open",
  "auth_user_created",
  "auth_response_lost_target_present",
  "handler_restored",
  "profile_created",
  "profile_replayed",
]);
const OPERATOR_ABORT_EXIT_CODE = 2;
const PSQL_TIMEOUT_MS = 60_000;
const MAX_BUFFER_BYTES = 2 * 1024 * 1024;
const AUTH_REQUEST_TIMEOUT_MS = 20_000;
const DEFAULT_POSTGRES_PORT = 5432;
const POSTGRES_SSL_MODES = new Set(["require", "verify-ca", "verify-full"]);
const POSTGRES_ENVIRONMENT_KEYS = new Set([
  "PGHOST", "PGHOSTADDR", "PGPORT", "PGDATABASE", "PGUSER", "PGPASSWORD",
  "PGPASSFILE", "PGSERVICE", "PGSERVICEFILE", "PGOPTIONS", "PGSSLMODE",
  "PGCONNECT_TIMEOUT", "PGAPPNAME", "PGCLIENTENCODING", "PG_COLOR",
]);
const PSQL_ARGUMENTS = Object.freeze([
  "-X", "-qAt", "-w", "-v", "ON_ERROR_STOP=1", "-f", "-",
]);
const CLIENT_OPTIONS = Object.freeze({
  auth: { autoRefreshToken: false, persistSession: false, detectSessionInUrl: false },
});
const SAFE_ERROR_CODES = new Set([
  "privileged_key_rejected",
  "target_password_rejected",
  "handler_rejected",
  "rate_limited",
  "auth_admin_unavailable",
  "response_lost_target_present",
  "target_creation_failed",
]);
const EVIDENCE_FORBIDDEN = /@|https?:|password|secret|service[_-]?role|token|cookie|authorization|[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}/i;

let createSupabaseClient = null;
let authHandlerGateActive = false;

class SafeFailure extends Error {
  constructor(code) {
    super(code);
    this.name = "SafeFailure";
    this.code = code;
  }
}

class RestoreAttemptFailure extends Error {
  constructor(category) {
    super(category);
    this.name = "RestoreAttemptFailure";
    this.category = category;
  }
}

function fail(code) {
  throw new SafeFailure(code);
}

function requireCondition(condition, code) {
  if (!condition) fail(code);
}

function normalizeEol(value) {
  return String(value).replace(/\r\n?/g, "\n");
}

function ensureSqlStatementTerminated(sqlText) {
  const normalized = normalizeEol(sqlText).trim();
  requireCondition(normalized.length > 0, "captured_sql_empty");
  return normalized.endsWith(";") ? normalized : `${normalized};`;
}

function assertCapturedFunctionStatementBoundary(sqlText) {
  const normalized = normalizeEol(sqlText).trim();
  requireCondition(
    /\$[A-Za-z_][A-Za-z0-9_]*\$\s*;\s*(?:do|select)\b/i.test(normalized),
    "captured_function_statement_boundary_rejected",
  );
  return normalized;
}

function assembleCapturedFunctionSql(snapshotDefinition, followingSql) {
  const following = normalizeEol(followingSql).trim();
  requireCondition(/^(?:do|select)\b/i.test(following), "captured_following_statement_rejected");
  return assertCapturedFunctionStatementBoundary(
    `${ensureSqlStatementTerminated(snapshotDefinition)}\n${following}`,
  );
}

function hashBuffer(value) {
  return crypto.createHash("sha256").update(value).digest("hex");
}

function hashTextMd5(value) {
  return crypto.createHash("md5").update(value, "utf8").digest("hex");
}

function sqlText(value) {
  requireCondition(typeof value === "string" && value.length > 0, "sql_text_invalid");
  return `'${value.replace(/'/g, "''")}'::text`;
}

function sqlUuid(value) {
  requireCondition(UUID_PATTERN.test(value), "sql_uuid_invalid");
  return `'${value}'::uuid`;
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
  )`;
}

function assertSafeEvidence(contents) {
  const normalized = normalizeEol(contents).trim();
  requireCondition(normalized.length > 0 && !EVIDENCE_FORBIDDEN.test(normalized), "unsafe_evidence_rejected");
  requireCondition(
    normalized.split("\n").every((line) => /^[A-Za-z0-9_.:-]+(?:\|[A-Za-z0-9_.:-]+)*$/.test(line)),
    "evidence_shape_rejected",
  );
  return `${normalized}\n`;
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
    database,
    username,
    password,
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
    PGDATABASE: connection.database,
    PGUSER: connection.username,
    PGPASSWORD: connection.password,
    PGSSLMODE: connection.sslmode,
    PGCONNECT_TIMEOUT: "10",
    PGOPTIONS: "-c statement_timeout=30000 -c lock_timeout=5000",
    PGAPPNAME: "sitaa_b3a_failure_target_bootstrap",
    PGCLIENTENCODING: "UTF8",
    PG_COLOR: "never",
  });
  return environment;
}

function spawnPsql(connection, sql) {
  return spawnSync("psql", PSQL_ARGUMENTS, {
    cwd: process.env.SITAA_B3A_REPO_ROOT,
    encoding: "utf8",
    env: postgresChildEnvironment(connection),
    input: `${normalizeEol(sql).trim()}\n`,
    windowsHide: true,
    timeout: PSQL_TIMEOUT_MS,
    maxBuffer: MAX_BUFFER_BYTES,
  });
}

function classifyPsqlFailure(result) {
  if (result?.error?.code === "ETIMEDOUT") return "database_process_timeout";
  const stderr = String(result?.stderr ?? "");
  if (/password authentication failed|no password supplied|fe_sendauth|contraseña/i.test(stderr)) {
    return "database_password_unavailable";
  }
  if (result?.status === 0 && !result?.error) return null;
  if (result?.status === 2) return "database_connection_failed";
  if (result?.status === 3) return "database_script_failed";
  return "database_check_failed";
}

function parsePsqlMarker(result, prefix) {
  const failureCode = classifyPsqlFailure(result);
  if (failureCode) fail(failureCode);
  const lines = normalizeEol(result.stdout ?? "").split("\n").map((line) => line.trim()).filter(Boolean);
  const matches = lines.filter((line) => line.startsWith(`${prefix}|`));
  requireCondition(matches.length === 1, "database_result_invalid");
  return matches[0].split("|");
}

function executeReadOnlySql(connection, sql, prefix) {
  const normalized = normalizeEol(sql).trim();
  requireCondition(/^begin;\nset transaction read only;/i.test(normalized), "sql_not_read_only");
  requireCondition(/\nrollback;$/i.test(normalized), "sql_missing_rollback");
  const withoutStrings = normalized.replace(/'[^']*'/g, "''");
  requireCondition(!/\b(insert|update|delete|alter|drop|truncate|grant|revoke|create|call|do)\b/i.test(withoutStrings), "sql_contains_write");
  console.log(`POSTGRES_READ_ONLY_GATE|${prefix}|STARTED`);
  const parts = parsePsqlMarker(spawnPsql(connection, normalized), prefix);
  console.log(`POSTGRES_READ_ONLY_GATE|${prefix}|APPROVED`);
  return parts;
}

function assertControlledMutation(sql, kind) {
  const normalized = normalizeEol(sql).trim();
  const withoutStrings = normalized.replace(/'([^']|'')*'/g, "''");
  const outsideDollarBodies = withoutStrings.replace(/\$([A-Za-z0-9_]*)\$[\s\S]*?\$\1\$/g, "$body$");
  requireCondition(/^begin;/i.test(normalized) && /\ncommit;$/i.test(normalized), "mutation_transaction_invalid");
  requireCondition((withoutStrings.match(/\bcommit\s*;/gi) ?? []).length === 1, "mutation_commit_count_invalid");
  if (kind === "handler_gate" || kind === "handler_restore") {
    requireCondition((outsideDollarBodies.match(/create\s+or\s+replace\s+function\s+public\.handle_sitaa_auth_user_created/gi) ?? []).length === 1, "handler_replacement_scope_rejected");
    requireCondition(!/\b(insert|update|delete|alter|drop|truncate|grant|revoke|call)\b/i.test(outsideDollarBodies), "handler_replacement_dml_rejected");
  } else if (kind === "profile") {
    requireCondition((withoutStrings.match(/insert\s+into\s+public\.profiles/gi) ?? []).length === 1, "profile_mutation_scope_rejected");
    requireCondition(!/create\s+or\s+replace|\binsert\s+into\s+(?!public\.profiles)|\bupdate\s+[a-z_]|\b(delete|alter|drop|truncate|grant|revoke|call)\b/i.test(withoutStrings), "profile_mutation_extra_write_rejected");
  } else {
    fail("mutation_kind_rejected");
  }
  return normalized;
}

function executeControlledMutation(connection, sql, prefix, kind) {
  const normalized = assertControlledMutation(sql, kind);
  console.log(`POSTGRES_CONTROLLED_MUTATION|${prefix}|STARTED`);
  const parts = parsePsqlMarker(spawnPsql(connection, normalized), prefix);
  console.log(`POSTGRES_CONTROLLED_MUTATION|${prefix}|APPROVED`);
  return parts;
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
          reject(new SafeFailure("operator_interrupted"));
          return;
        }
        if (character === "\r" || character === "\n") {
          process.stdin.off("data", onData);
          process.stdout.write("\n");
          resolve(value);
          return;
        }
        if (character === "\u007f" || character === "\b") {
          if (value.length > 0) {
            const current = Array.from(value);
            current.pop();
            value = current.join("");
            process.stdout.write("\b \b");
          }
          return;
        }
        if (/[^\p{Cc}\p{Cf}\p{Cs}]/u.test(character)) {
          value += character;
          process.stdout.write("*");
        }
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

function readSupabaseJsVersion(repoRoot) {
  const rootPackage = JSON.parse(fs.readFileSync(path.join(repoRoot, "package.json"), "utf8"));
  const installedPackage = JSON.parse(fs.readFileSync(
    path.join(repoRoot, "node_modules", "@supabase", "supabase-js", "package.json"),
    "utf8",
  ));
  const declared = String(rootPackage.dependencies?.["@supabase/supabase-js"] ?? "").replace(/^[~^]/, "");
  requireCondition(declared === EXPECTED_SUPABASE_JS_VERSION && installedPackage.version === EXPECTED_SUPABASE_JS_VERSION, "supabase_js_version_rejected");
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

function isThreeSegmentJwt(value) {
  return typeof value === "string" && /^[^.]+\.[^.]+\.[^.]+$/.test(value);
}

function validatePublicApiKey(value) {
  requireCondition(
    typeof value === "string"
      && (/^sb_publishable_.+$/.test(value) || isThreeSegmentJwt(value)),
    "publishable_key_shape_rejected",
  );
  return value;
}

function validatePrivilegedApiKey(value) {
  requireCondition(
    typeof value === "string"
      && (/^sb_secret_.+$/.test(value) || isThreeSegmentJwt(value)),
    "privileged_key_shape_rejected",
  );
  return value;
}

function isOpaqueApiKey(value) {
  return typeof value === "string"
    && (value.startsWith("sb_publishable_") || value.startsWith("sb_secret_"));
}

function boundedRequestInit(init = {}, timeoutMs = AUTH_REQUEST_TIMEOUT_MS) {
  requireCondition(Number.isSafeInteger(timeoutMs) && timeoutMs > 0, "auth_request_timeout_invalid");
  const timeoutSignal = AbortSignal.timeout(timeoutMs);
  const signal = init.signal
    ? AbortSignal.any([init.signal, timeoutSignal])
    : timeoutSignal;
  return { ...init, headers: new Headers(init.headers), signal };
}

function apiKeyAwareRequestInit(apiKey, init = {}, timeoutMs = AUTH_REQUEST_TIMEOUT_MS) {
  const requestInit = boundedRequestInit(init, timeoutMs);
  if (
    isOpaqueApiKey(apiKey)
      && requestInit.headers.get("authorization") === `Bearer ${apiKey}`
  ) {
    requestInit.headers.delete("authorization");
  }
  return requestInit;
}

function boundedFetchWith(fetchImplementation, apiKey, input, init = {}, timeoutMs = AUTH_REQUEST_TIMEOUT_MS) {
  requireCondition(typeof fetchImplementation === "function", "auth_fetch_implementation_invalid");
  return fetchImplementation(input, apiKeyAwareRequestInit(apiKey, init, timeoutMs));
}

function createApiKeyAwareBoundedFetch(
  apiKey,
  fetchImplementation = globalThis.fetch,
  timeoutMs = AUTH_REQUEST_TIMEOUT_MS,
) {
  requireCondition(typeof fetchImplementation === "function", "auth_fetch_implementation_invalid");
  return (input, init = {}) => boundedFetchWith(
    fetchImplementation,
    apiKey,
    input,
    init,
    timeoutMs,
  );
}

function createClient(projectUrl, key) {
  requireCondition(typeof createSupabaseClient === "function", "supabase_js_not_loaded");
  return createSupabaseClient(projectUrl, key, {
    ...CLIENT_OPTIONS,
    global: { fetch: createApiKeyAwareBoundedFetch(key) },
  });
}

function authRequestFailureCode(error, fallbackCode) {
  const name = typeof error?.name === "string" ? error.name : "";
  return name === "AbortError" || name === "TimeoutError"
    ? "auth_request_timeout"
    : fallbackCode;
}

function parseFixtureUsers(contents) {
  const rows = normalizeEol(contents).split("\n").map((line) => line.trim())
    .filter((line) => line.startsWith("AUTH_CREATED|"));
  requireCondition(rows.length === 2, "fixture_user_count_invalid");
  const users = new Map();
  for (const row of rows) {
    const fields = row.split("|");
    requireCondition(fields.length === 4, "fixture_user_shape_invalid");
    const [, alias, email, id] = fields;
    requireCondition(new Set(["admin_a", "admin_b"]).has(alias) && !users.has(alias), "fixture_alias_invalid");
    requireCondition(/^[a-z0-9][a-z0-9._+-]*@example\.invalid$/.test(email) && UUID_PATTERN.test(id), "fixture_identity_invalid");
    users.set(alias, { email, id });
  }
  requireCondition(users.get("admin_a").id !== users.get("admin_b").id, "fixture_users_not_distinct");
  return users;
}

function loadAdminFixtures(repoRoot) {
  const filePath = path.join(repoRoot, "supabase", "reconciliation", "b3a_matrix_hosted_auth_users.local.txt");
  requireCondition(fs.existsSync(filePath), "fixture_users_missing");
  return parseFixtureUsers(fs.readFileSync(filePath, "utf8"));
}

function baselineSql(adminAId, adminBId) {
  const adminA = sqlUuid(adminAId);
  const adminB = sqlUuid(adminBId);
  return `
begin;
set transaction read only;
select concat_ws('|','FAILURE_TARGET_BOOTSTRAP_BASELINE',
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
  (select count(*) from public.admin_audit_events where action_code in
    ('account_deactivated','account_reactivated','account_auth_suspended','account_auth_restored','account_auth_suspension_failed','account_auth_restoration_failed')),
  (select count(*) from public.admin_audit_events where action_code in
    ('account_auth_suspended','account_auth_restored','account_auth_suspension_failed','account_auth_restoration_failed') and outcome='failure'),
  (select count(*) from auth.users where lower(email) ~ '${TARGET_EMAIL_SQL_PATTERN}'),
  md5(pg_get_functiondef('${HANDLER_SIGNATURE}'::regprocedure)),
  pg_get_userbyid(p.proowner),
  case when p.prosecdef then 1 else 0 end,
  p.provolatile::text,
  case when p.proconfig=array['search_path=pg_catalog, public, auth']::text[] then 1 else 0 end,
  case when coalesce((select string_agg(pg_get_userbyid(a.grantee),',' order by pg_get_userbyid(a.grantee))
    from aclexplode(coalesce(p.proacl,acldefault('f',p.proowner))) a
    where a.privilege_type='EXECUTE' and not a.is_grantable),'')='postgres,service_role'
    and not exists(select 1 from aclexplode(coalesce(p.proacl,acldefault('f',p.proowner))) a
      where a.privilege_type<>'EXECUTE' or a.is_grantable) then 1 else 0 end,
  (select count(*) from pg_trigger t where t.tgrelid='auth.users'::regclass and not t.tgisinternal),
  case when ${exactAuthUsersTriggerContractSql()} then 2 else 0 end
)
from pg_proc p where p.oid='${HANDLER_SIGNATURE}'::regprocedure;
rollback;`;
}

function assertBaseline(parts) {
  requireCondition(parts.length === 21 && parts[0] === "FAILURE_TARGET_BOOTSTRAP_BASELINE", "baseline_shape_rejected");
  requireCondition(
    parts.slice(1).join("|") === `2|2|2|2|2|2|2|0|0|4|0|0|${EXPECTED_HANDLER_MD5}|postgres|1|v|1|1|2|2`,
    "baseline_state_rejected",
  );
  console.log("FAILURE_TARGET_BOOTSTRAP_BASELINE|APPROVED");
}

function handlerCaptureSql() {
  return `
begin;
set transaction read only;
select concat_ws('|','AUTH_HANDLER_CAPTURE',p.oid::text,
  replace(encode(convert_to(coalesce(p.proacl::text,'<NULL>'),'UTF8'),'base64'),E'\\n',''),
  pg_get_userbyid(p.proowner),case when p.prosecdef then 1 else 0 end,p.provolatile::text,
  replace(encode(convert_to(coalesce(p.proconfig::text,'<NULL>'),'UTF8'),'base64'),E'\\n',''),
  md5(pg_get_functiondef(p.oid)),
  case when ${exactAuthUsersTriggerContractSql()} then 1 else 0 end,
  replace(encode(convert_to(pg_get_functiondef(p.oid),'UTF8'),'base64'),E'\\n',''))
from pg_proc p where p.oid='${HANDLER_SIGNATURE}'::regprocedure;
rollback;`;
}

function parseHandlerCapture(parts) {
  requireCondition(parts.length === 10 && parts[0] === "AUTH_HANDLER_CAPTURE", "handler_capture_shape_rejected");
  const definition = Buffer.from(parts[9], "base64").toString("utf8");
  const metadata = {
    oid: parts[1],
    acl: Buffer.from(parts[2], "base64").toString("utf8"),
    owner: parts[3],
    securityDefiner: parts[4] === "1",
    volatility: parts[5],
    proconfig: Buffer.from(parts[6], "base64").toString("utf8"),
    md5: parts[7],
    triggerContract: parts[8] === "1",
    definition: normalizeEol(definition).trim(),
  };
  requireCondition(/^\d+$/.test(metadata.oid), "handler_oid_rejected");
  requireCondition(
    metadata.owner === "postgres" && metadata.securityDefiner && metadata.volatility === "v"
      && metadata.proconfig === '{"search_path=pg_catalog, public, auth"}'
      && metadata.acl === EXPECTED_HANDLER_ACL
      && metadata.md5 === EXPECTED_HANDLER_MD5
      && metadata.triggerContract
      && /^CREATE OR REPLACE FUNCTION public\.handle_sitaa_auth_user_created\(\)/i.test(metadata.definition)
      && hashTextMd5(`${metadata.definition}\n`) === metadata.md5,
    "handler_capture_contract_rejected",
  );
  return metadata;
}

function generateTargetEmail() {
  const stamp = new Date().toISOString().replace(/[-:.TZ]/g, "").toLowerCase();
  return `b3a-failure-target-${stamp}-${crypto.randomBytes(6).toString("hex")}@example.invalid`;
}

function validateRepair(value, { allowRecoverablePredecessor = false } = {}) {
  requireCondition(value && typeof value === "object" && !Array.isArray(value), "repair_shape_rejected");
  requireCondition(Object.keys(value).sort().join("|") === [...REPAIR_KEYS].sort().join("|"), "repair_keys_rejected");
  requireCondition(
    (
      value.version === CURRENT_BOOTSTRAP_VERSION
        || (allowRecoverablePredecessor && value.version === RECOVERABLE_PREDECESSOR_VERSION)
    ) && TARGET_EMAIL_PATTERN.test(value.target_email),
    "repair_identity_rejected",
  );
  requireCondition(value.target_uuid === null || UUID_PATTERN.test(value.target_uuid), "repair_uuid_rejected");
  requireCondition(/^\d+$/.test(value.original_oid) && MD5_PATTERN.test(value.original_md5), "repair_handler_identity_rejected");
  requireCondition(SHA256_PATTERN.test(value.snapshot_sha256), "repair_snapshot_hash_rejected");
  requireCondition(
    typeof value.original_acl_base64 === "string"
      && /^[A-Za-z0-9+/]+={0,2}$/.test(value.original_acl_base64)
      && Buffer.from(value.original_acl_base64, "base64").toString("utf8") === EXPECTED_HANDLER_ACL,
    "repair_acl_rejected",
  );
  requireCondition(value.original_md5 === EXPECTED_HANDLER_MD5, "repair_handler_md5_rejected");
  requireCondition(
    value.snapshot_relative_path === "supabase/reconciliation/b3a_matrix_failure_recovery_target_handler_snapshot.local.sql",
    "repair_snapshot_path_rejected",
  );
  requireCondition(REPAIR_PHASES.has(value.phase), "repair_phase_rejected");
  const nonAclFields = Object.fromEntries(
    Object.entries(value).filter(([key]) => key !== "original_acl_base64"),
  );
  requireCondition(
    !/password|secret|service[_-]?key|publishable|uri|url|token|cookie|header|authorization/i.test(
      JSON.stringify(nonAclFields),
    ),
    "repair_sensitive_field_rejected",
  );
  return value;
}

function repairAcl(value, options = {}) {
  validateRepair(value, options);
  return Buffer.from(value.original_acl_base64, "base64").toString("utf8");
}

function bundleJournalPaths(repairPath, snapshotPath) {
  return Object.freeze({
    repairPath,
    snapshotPath,
    repairNext: repairPath.replace(/\.local\.json$/, ".next.local.json"),
    repairPrevious: repairPath.replace(/\.local\.json$/, ".previous.local.json"),
    snapshotNext: snapshotPath.replace(/\.local\.sql$/, ".next.local.sql"),
    snapshotPrevious: snapshotPath.replace(/\.local\.sql$/, ".previous.local.sql"),
  });
}

function assertLocalRepairJsonGitignore(repoRoot) {
  const gitignorePath = path.join(repoRoot, ".gitignore");
  requireCondition(fs.existsSync(gitignorePath), "gitignore_fixture_missing");
  const rules = normalizeEol(fs.readFileSync(gitignorePath, "utf8"))
    .split("\n")
    .map((line) => line.trim())
    .filter((line) => line && !line.startsWith("#"));
  requireCondition(
    rules.filter((rule) => rule === LOCAL_JSON_GITIGNORE_RULE).length === 1
      && !rules.includes("*.local.json")
      && !rules.includes("supabase/reconciliation/*.json"),
    "local_json_gitignore_rule_rejected",
  );
  const repairJsonMatcher = /^supabase\/reconciliation\/[^/]*\.local\.json$/;
  const expectedNames = [
    "b3a_matrix_failure_recovery_target_handler_repair.local.json",
    "b3a_matrix_failure_recovery_target_handler_repair.next.local.json",
    "b3a_matrix_failure_recovery_target_handler_repair.previous.local.json",
  ];
  requireCondition(
    expectedNames.every((name) => repairJsonMatcher.test(`supabase/reconciliation/${name}`))
      && !repairJsonMatcher.test("supabase/reconciliation/versioned/baseline.local.json")
      && !repairJsonMatcher.test("docs/reference.local.json"),
    "local_json_gitignore_matching_fixture_rejected",
  );
}

function readRepairFile(filePath, options = {}) {
  requireCondition(fs.existsSync(filePath), "handler_repair_file_missing");
  let parsed;
  try {
    parsed = JSON.parse(fs.readFileSync(filePath, "utf8"));
  } catch {
    fail("handler_repair_file_invalid");
  }
  return validateRepair(parsed, options);
}

function validateSnapshotText(definition) {
  const normalized = `${normalizeEol(definition).trim()}\n`;
  requireCondition(/^CREATE OR REPLACE FUNCTION public\.handle_sitaa_auth_user_created\(\)/i.test(normalized), "handler_snapshot_definition_rejected");
  requireCondition(!/^\uFEFF/.test(normalized), "handler_snapshot_bom_rejected");
  return normalized;
}

function validateBundleFiles(repairFile, snapshotFile, options = {}) {
  const repair = readRepairFile(repairFile, options);
  requireCondition(fs.existsSync(snapshotFile), "handler_snapshot_missing");
  const snapshot = validateSnapshotText(fs.readFileSync(snapshotFile, "utf8"));
  requireCondition(
    hashBuffer(Buffer.from(snapshot, "utf8")) === repair.snapshot_sha256,
    "handler_snapshot_hash_rejected",
  );
  requireCondition(repair.original_md5 === EXPECTED_HANDLER_MD5, "repair_handler_md5_rejected");
  requireCondition(repair.original_acl_base64 === Buffer.from(EXPECTED_HANDLER_ACL, "utf8").toString("base64"), "repair_acl_roundtrip_rejected");
  return { repair, snapshot };
}

function tryValidateBundleFiles(repairFile, snapshotFile, options = {}) {
  if (!fs.existsSync(repairFile) || !fs.existsSync(snapshotFile)) return null;
  try {
    return validateBundleFiles(repairFile, snapshotFile, options);
  } catch {
    return null;
  }
}

function removeIfExists(filePath) {
  if (fs.existsSync(filePath)) fs.unlinkSync(filePath);
}

function recoverRepairBundle(repairPath, snapshotPath, options = {}) {
  const journal = bundleJournalPaths(repairPath, snapshotPath);
  const artifactPaths = Object.values(journal);
  if (artifactPaths.every((filePath) => !fs.existsSync(filePath))) return "absent";
  const journalOnly = [
    journal.repairNext,
    journal.repairPrevious,
    journal.snapshotNext,
    journal.snapshotPrevious,
  ];
  if (tryValidateBundleFiles(journal.repairPath, journal.snapshotPath, options)) {
    for (const filePath of journalOnly) removeIfExists(filePath);
    return "current";
  }

  const candidates = [
    { state: "recovered_next", repair: journal.repairNext, snapshot: journal.snapshotNext },
    { state: "recovered_next_with_current_snapshot", repair: journal.repairNext, snapshot: journal.snapshotPath },
    { state: "recovered_previous", repair: journal.repairPrevious, snapshot: journal.snapshotPrevious },
    { state: "recovered_previous_with_current_snapshot", repair: journal.repairPrevious, snapshot: journal.snapshotPath },
  ];
  const candidate = candidates.find(({ repair, snapshot }) => tryValidateBundleFiles(repair, snapshot, options));
  if (candidate) {
    if (candidate.snapshot !== journal.snapshotPath) {
      removeIfExists(journal.snapshotPath);
      fs.renameSync(candidate.snapshot, journal.snapshotPath);
    }
    if (candidate.repair !== journal.repairPath) {
      removeIfExists(journal.repairPath);
      fs.renameSync(candidate.repair, journal.repairPath);
    }
    validateBundleFiles(journal.repairPath, journal.snapshotPath, options);
    for (const filePath of journalOnly) removeIfExists(filePath);
    return candidate.state;
  }

  fail("handler_repair_bundle_corrupt");
}

function publishRepairBundle(repairPath, snapshotPath, repairValue, definition, interruptAt = null) {
  const journal = bundleJournalPaths(repairPath, snapshotPath);
  requireCondition(recoverRepairBundle(repairPath, snapshotPath) === "absent", "handler_repair_file_exists");
  const snapshot = validateSnapshotText(definition);
  const snapshotSha256 = hashBuffer(Buffer.from(snapshot, "utf8"));
  requireCondition(
    repairValue.snapshot_sha256 === undefined || repairValue.snapshot_sha256 === snapshotSha256,
    "repair_snapshot_hash_rejected",
  );
  const repair = validateRepair({ ...repairValue, snapshot_sha256: snapshotSha256 });
  try {
    fs.writeFileSync(journal.repairNext, `${JSON.stringify(repair, null, 2)}\n`, { encoding: "utf8", flag: "wx" });
    fs.writeFileSync(journal.snapshotNext, snapshot, { encoding: "utf8", flag: "wx" });
    validateBundleFiles(journal.repairNext, journal.snapshotNext);
    if (interruptAt === "after_next") throw new Error("fixture_interrupt_after_next");
    fs.renameSync(journal.snapshotNext, journal.snapshotPath);
    if (interruptAt === "after_snapshot") throw new Error("fixture_interrupt_after_snapshot");
    fs.renameSync(journal.repairNext, journal.repairPath);
    if (interruptAt === "after_repair") throw new Error("fixture_interrupt_after_repair");
  } catch (error) {
    const recovered = recoverRepairBundle(repairPath, snapshotPath);
    requireCondition(recovered !== "absent", "bundle_publication_interrupted");
    void error;
  }
  validateBundleFiles(journal.repairPath, journal.snapshotPath);
  return readRepairFile(journal.repairPath);
}

function updateRepair(repairPath, snapshotPath, changes, interruptAt = null, options = {}) {
  recoverRepairBundle(repairPath, snapshotPath, options);
  const journal = bundleJournalPaths(repairPath, snapshotPath);
  const current = validateBundleFiles(repairPath, snapshotPath, options).repair;
  const updated = validateRepair({
    ...current,
    ...changes,
    version: CURRENT_BOOTSTRAP_VERSION,
  });
  try {
    fs.writeFileSync(journal.repairNext, `${JSON.stringify(updated, null, 2)}\n`, { encoding: "utf8", flag: "wx" });
    validateBundleFiles(journal.repairNext, snapshotPath);
    if (interruptAt === "after_next") throw new Error("fixture_interrupt_update_after_next");
    fs.renameSync(repairPath, journal.repairPrevious);
    if (interruptAt === "after_previous") throw new Error("fixture_interrupt_update_after_previous");
    fs.renameSync(journal.repairNext, repairPath);
    if (interruptAt === "after_current") throw new Error("fixture_interrupt_update_after_current");
  } catch (error) {
    recoverRepairBundle(repairPath, snapshotPath, options);
    void error;
  }
  validateBundleFiles(repairPath, snapshotPath);
  removeIfExists(journal.repairPrevious);
  return readRepairFile(repairPath);
}

function readRepair(repairPath, snapshotPath, options = {}) {
  requireCondition(recoverRepairBundle(repairPath, snapshotPath, options) !== "absent", "handler_repair_file_missing");
  return validateBundleFiles(repairPath, snapshotPath, options).repair;
}

function handlerGateSql(targetEmail, metadata) {
  const email = sqlText(targetEmail);
  const acl = sqlText(metadata.acl);
  return `
begin;
set local lock_timeout='5s';
set local statement_timeout='60s';
do $guard$
begin
  if current_user<>'postgres' or session_user<>'postgres' then
    raise exception 'sitaa_target_bootstrap_requires_postgres' using errcode='42501';
  end if;
  if md5(pg_get_functiondef('${HANDLER_SIGNATURE}'::regprocedure))<>'${EXPECTED_HANDLER_MD5}' then
    raise exception 'sitaa_target_bootstrap_handler_drift' using errcode='55000';
  end if;
  if (select count(*) from auth.users)<>2
     or (select count(*) from auth.identities)<>2
     or (select count(*) from public.profiles)<>2
     or (select count(*) from public.role_assignments)<>2
     or (select count(*) from public.admin_auth_operations)<>2
     or (select count(*) from public.admin_audit_events where action_code in
       ('account_deactivated','account_reactivated','account_auth_suspended','account_auth_restored','account_auth_suspension_failed','account_auth_restoration_failed'))<>4
     or exists(select 1 from public.admin_auth_operations where status in ('open','processing','retryable_failure'))
     or exists(select 1 from auth.users where lower(email) ~ '${TARGET_EMAIL_SQL_PATTERN}') then
    raise exception 'sitaa_target_bootstrap_inventory_conflict' using errcode='55000';
  end if;
end;
$guard$;
create or replace function public.handle_sitaa_auth_user_created()
returns trigger
language plpgsql
volatile
security definer
set search_path = pg_catalog, public, auth
as $target_bootstrap_gate$
declare normalized_email text;
begin
  if tg_op<>'INSERT' or tg_table_schema<>'auth' or tg_table_name<>'users' then
    raise exception 'sitaa_target_bootstrap_invalid_context' using errcode='55000';
  end if;
  normalized_email:=lower(btrim(coalesce(new.email::text,'')));
  if normalized_email<>${email} then
    raise exception 'sitaa_target_bootstrap_email_not_allowed' using errcode='42501';
  end if;
  if (select count(*) from auth.users where id<>new.id)<>2
     or (select count(*) from auth.users)<>3
     or (select count(*) from auth.identities)<>2
     or (select count(*) from public.profiles)<>2
     or (select count(*) from public.role_assignments)<>2
     or (select count(*) from public.admin_auth_operations)<>2
     or (select count(*) from public.admin_audit_events where action_code in
       ('account_deactivated','account_reactivated','account_auth_suspended','account_auth_restored','account_auth_suspension_failed','account_auth_restoration_failed'))<>4
     or exists(select 1 from public.admin_auth_operations where status in ('open','processing','retryable_failure'))
     or exists(select 1 from public.profiles where lower(email)=${email}) then
    raise exception 'sitaa_target_bootstrap_insert_inventory_conflict' using errcode='55000';
  end if;
  return new;
end;
$target_bootstrap_gate$;
do $post$
declare p pg_proc%rowtype;
begin
  select * into strict p from pg_proc where oid='${HANDLER_SIGNATURE}'::regprocedure;
  if p.oid<>${metadata.oid}::oid or coalesce(p.proacl::text,'<NULL>')<>${acl}
     or pg_get_userbyid(p.proowner)<>'postgres' or not p.prosecdef or p.provolatile::text<>'v'
     or p.proconfig<>array['search_path=pg_catalog, public, auth']::text[]
     or position('sitaa_target_bootstrap_email_not_allowed' in pg_get_functiondef(p.oid))=0
     or not ${exactAuthUsersTriggerContractSql()} then
    raise exception 'sitaa_target_bootstrap_gate_contract_rejected' using errcode='55000';
  end if;
end;
$post$;
select 'AUTH_HANDLER_GATE|'||case when md5(pg_get_functiondef('${HANDLER_SIGNATURE}'::regprocedure))<>'${EXPECTED_HANDLER_MD5}' then '1' else '0' end;
commit;`;
}

function handlerRestoreSql(snapshotDefinition, metadata) {
  const acl = sqlText(metadata.acl);
  const restoreAndVerify = assembleCapturedFunctionSql(snapshotDefinition, `
do $verify$
declare p pg_proc%rowtype;
begin
  select * into strict p from pg_proc where oid='${HANDLER_SIGNATURE}'::regprocedure;
  if p.oid<>${metadata.oid}::oid or coalesce(p.proacl::text,'<NULL>')<>${acl}
     or pg_get_userbyid(p.proowner)<>'postgres' or not p.prosecdef or p.provolatile::text<>'v'
     or p.proconfig<>array['search_path=pg_catalog, public, auth']::text[]
     or md5(pg_get_functiondef(p.oid))<>'${EXPECTED_HANDLER_MD5}'
     or position('sitaa_target_bootstrap_email_not_allowed' in pg_get_functiondef(p.oid))>0
     or not ${exactAuthUsersTriggerContractSql()} then
    raise exception 'sitaa_target_bootstrap_restore_rejected' using errcode='55000';
  end if;
end;
$verify$;`);
  return `
begin;
set local lock_timeout='5s';
set local statement_timeout='60s';
${restoreAndVerify}
select 'AUTH_HANDLER_RESTORED|1';
commit;`;
}

function classifyRestoreProcessResult(result) {
  if (result?.status === 0 && !result?.error) return null;
  const stderr = String(result?.stderr ?? "").toLowerCase();
  if (/syntax error|sqlstate\s*42601|\b42601\b/.test(stderr)) return "syntax_error";
  if (/lock timeout|lock_not_available|sqlstate\s*55p03|\b55p03\b/.test(stderr)) return "lock_timeout";
  if (/statement timeout|query_canceled|sqlstate\s*57014|\b57014\b/.test(stderr)) return "statement_timeout";
  if (/permission denied|must be owner|insufficient_privilege|sqlstate\s*42501|\b42501\b/.test(stderr)) {
    return "permission_rejected";
  }
  if (/sitaa_target_bootstrap_restore_rejected|sqlstate\s*55000|\b55000\b/.test(stderr)) {
    return "restore_contract_rejected";
  }
  if (result?.error || result?.status === 2) return "process_unavailable";
  return "unknown_restore_failure";
}

function classifyRestoreError(error) {
  if (error instanceof RestoreAttemptFailure) return error.category;
  if (error instanceof SafeFailure) {
    if (/^(?:handler_restore|captured_|mutation_|repair_|handler_repair_|database_result_invalid)/.test(error.code)) {
      return "restore_contract_rejected";
    }
    if (error.code === "database_password_unavailable") return "permission_rejected";
    if (/^database_(?:process_timeout|connection_failed|check_failed)$/.test(error.code)) {
      return "process_unavailable";
    }
  }
  return "unknown_restore_failure";
}

function restoreAttemptRejectionLines(attempt, error) {
  const category = classifyRestoreError(error);
  return [
    `AUTH_HANDLER_RESTORE_ATTEMPT|${attempt}|REJECTED`,
    `AUTH_HANDLER_RESTORE_DIAGNOSTIC|${attempt}|${category}`,
  ];
}

function executeHandlerRestoreMutation(connection, sql) {
  const normalized = assertControlledMutation(sql, "handler_restore");
  const result = spawnPsql(connection, normalized);
  const category = classifyRestoreProcessResult(result);
  if (category) throw new RestoreAttemptFailure(category);
  let parts;
  try {
    parts = parsePsqlMarker(result, "AUTH_HANDLER_RESTORED");
  } catch (error) {
    throw new RestoreAttemptFailure(classifyRestoreError(error));
  }
  console.log("POSTGRES_CONTROLLED_MUTATION|AUTH_HANDLER_RESTORED|APPROVED");
  return parts;
}

function restoreHandler(connection, repairPath, snapshotPath, options = {}) {
  const repair = readRepair(repairPath, snapshotPath, options);
  const snapshot = validateBundleFiles(repairPath, snapshotPath, options).snapshot;
  const metadata = {
    oid: repair.original_oid,
    acl: repairAcl(repair, options),
    md5: repair.original_md5,
  };
  for (let attempt = 1; attempt <= 2; attempt += 1) {
    try {
      const parts = executeHandlerRestoreMutation(
        connection,
        handlerRestoreSql(snapshot, metadata),
      );
      requireCondition(parts.length === 2 && parts[1] === "1", "handler_restore_result_rejected");
      updateRepair(repairPath, snapshotPath, { phase: "handler_restored" }, null, options);
      console.log(`AUTH_HANDLER_RESTORE_ATTEMPT|${attempt}|APPROVED`);
      console.log("AUTH_HANDLER_STATE|CANONICAL");
      return true;
    } catch (error) {
      for (const line of restoreAttemptRejectionLines(attempt, error)) console.log(line);
    }
  }
  console.error("AUTH_HANDLER_REPAIR_REQUIRED");
  fail("auth_handler_repair_required");
}

async function listAllAuthUsers(serviceClient) {
  requireCondition(!authHandlerGateActive, "auth_inventory_during_handler_gate_rejected");
  const users = [];
  for (let page = 1; page <= 100; page += 1) {
    const result = await serviceClient.auth.admin.listUsers({ page, perPage: 1000 });
    if (result.error) fail("auth_admin_unavailable");
    const pageUsers = result.data?.users ?? [];
    users.push(...pageUsers);
    if (pageUsers.length < 1000) return users;
  }
  fail("auth_inventory_unbounded");
}

function classifyCreateError(error) {
  const status = Number(error?.status ?? error?.statusCode ?? 0);
  const code = String(error?.code ?? "").toLowerCase();
  const message = String(error?.message ?? "").toLowerCase();
  if (status === 401 || status === 403 || /service|jwt|apikey|unauthorized/.test(`${code} ${message}`)) return "privileged_key_rejected";
  if (/password|weak/.test(`${code} ${message}`)) return "target_password_rejected";
  if (status === 429 || /rate/.test(`${code} ${message}`)) return "rate_limited";
  if (/42501|handler|sitaa_/.test(`${code} ${message}`)) return "handler_rejected";
  if (status >= 500 || /fetch|network|timeout|unavailable/.test(`${code} ${message}`)) return "auth_admin_unavailable";
  return "target_creation_failed";
}

function resolveCreateOutcome({ attempt, matches }) {
  requireCondition(Array.isArray(matches), "target_inventory_invalid");
  if (matches.length > 1) fail("target_inventory_duplicated");
  if (matches.length === 1) {
    return {
      user: matches[0],
      classification: attempt.succeeded ? "created" : "response_lost_target_present",
    };
  }
  if (!attempt.succeeded) fail(attempt.errorCode);
  fail("target_creation_failed");
}

function provisioningState({ userCount, profileCount }) {
  requireCondition(userCount === 1 && (profileCount === 0 || profileCount === 1), "resume_inventory_rejected");
  return profileCount === 0 ? "auth_only_profile_missing" : "profile_already_created";
}

function resumeProvisioningPrecheckSql(targetId, targetEmail, adminAId, adminBId) {
  const target = sqlUuid(targetId);
  const email = sqlText(targetEmail);
  const adminA = sqlUuid(adminAId);
  const adminB = sqlUuid(adminBId);
  const names = sqlText(TARGET_FIRST_NAMES);
  return `
begin;
set transaction read only;
select concat_ws('|','FAILURE_TARGET_RESUME_PRECHECK',
  (select count(*) from auth.users),(select count(*) from auth.identities),
  (select count(*) from public.profiles),(select count(*) from public.role_assignments),
  (select count(*) from public.profiles p where p.id in (${adminA},${adminB}) and p.account_status='active'
    and p.is_active and public.is_exact_b1_account_admin_profile_b2b(p.id)),
  (select count(*) from auth.users where id=${target} and lower(email)=${email}
    and email_confirmed_at is not null and banned_until is null
    and raw_app_meta_data->>'provider'='email' and raw_app_meta_data->'providers'='["email"]'::jsonb
    and raw_app_meta_data->>'sitaa_account_kind'='technical' and raw_app_meta_data->>'sitaa_first_names'=${names}),
  (select count(*) from auth.identities where user_id=${target} and provider='email'
    and lower(identity_data->>'email')=${email}),
  (select count(*) from public.profiles where id=${target} and lower(email)=${email}
    and first_names=${names} and paternal_surname is null and maternal_surname is null and full_name=${names}
    and person_type is null and primary_program_id is null and institutional_id_type is null
    and institutional_id_value is null and account_kind='technical' and account_status='active'
    and is_active and activated_at is not null and deactivated_at is null),
  (select count(*) from public.role_assignments where user_id=${target}),
  (select count(*) from public.admin_auth_operations where target_profile_id=${target}),
  md5(pg_get_functiondef('${HANDLER_SIGNATURE}'::regprocedure)),
  case when ${exactAuthUsersTriggerContractSql()} then 2 else 0 end);
rollback;`;
}

function assertResumeProvisioningPrecheck(parts) {
  requireCondition(
    parts.length === 13 && parts[0] === "FAILURE_TARGET_RESUME_PRECHECK",
    "resume_precheck_shape_rejected",
  );
  const profileCount = Number(parts[8]);
  requireCondition(
    (profileCount === 0 || profileCount === 1)
      && parts.slice(1, 3).join("|") === "3|3"
      && parts[3] === String(2 + profileCount)
      && parts.slice(4, 8).join("|") === "2|2|1|1"
      && parts.slice(9, 11).join("|") === "0|0"
      && parts[11] === EXPECTED_HANDLER_MD5
      && parts[12] === "2",
    "resume_precheck_state_rejected",
  );
  console.log(`FAILURE_TARGET_RESUME_STATE|${profileCount === 0 ? "1/1/0" : "1/1/1"}|APPROVED`);
  return provisioningState({ userCount: 1, profileCount });
}

function profileProvisionSql(targetId, targetEmail) {
  const target = sqlUuid(targetId);
  const email = sqlText(targetEmail);
  const names = sqlText(TARGET_FIRST_NAMES);
  return `
begin;
set local lock_timeout='5s';
set local statement_timeout='60s';
do $profile$
declare auth_row auth.users%rowtype; existing public.profiles%rowtype; outcome text;
begin
  select * into strict auth_row from auth.users where id=${target} and lower(email)=${email} for update;
  if auth_row.email_confirmed_at is null or auth_row.banned_until is not null
     or auth_row.raw_app_meta_data->>'provider'<>'email'
     or auth_row.raw_app_meta_data->'providers'<>'["email"]'::jsonb
     or auth_row.raw_app_meta_data->>'sitaa_account_kind'<>'technical'
     or auth_row.raw_app_meta_data->>'sitaa_first_names'<>${names}
     or (select count(*) from auth.users where lower(email)=${email})<>1
     or (select count(*) from auth.identities where user_id=${target} and provider='email' and lower(identity_data->>'email')=${email})<>1
     or exists(select 1 from public.profiles where lower(email)=${email} and id<>${target})
     or exists(select 1 from public.role_assignments where user_id=${target})
     or exists(select 1 from public.admin_auth_operations where target_profile_id=${target}) then
    raise exception 'sitaa_target_bootstrap_profile_precondition_rejected' using errcode='55000';
  end if;
  select * into existing from public.profiles where id=${target} for update;
  if not found then
    insert into public.profiles(
      id,email,first_names,paternal_surname,maternal_surname,full_name,person_type,
      primary_program_id,institutional_id_type,institutional_id_value,account_kind,
      account_status,is_active,activated_at,deactivated_at
    ) values (
      ${target},${email},${names},null,null,${names},null,null,null,null,
      'technical','active',true,auth_row.email_confirmed_at,null
    );
    outcome:='created';
  elsif lower(existing.email)=${email} and existing.first_names=${names}
    and existing.paternal_surname is null and existing.maternal_surname is null
    and existing.full_name=${names} and existing.person_type is null
    and existing.primary_program_id is null and existing.institutional_id_type is null
    and existing.institutional_id_value is null and existing.account_kind='technical'
    and existing.account_status='active' and existing.is_active
    and existing.activated_at=auth_row.email_confirmed_at and existing.deactivated_at is null then
    outcome:='replayed';
  else
    raise exception 'sitaa_target_bootstrap_profile_conflict' using errcode='55000';
  end if;
  perform set_config('sitaa.target_profile_outcome',outcome,true);
end;
$profile$;
select 'FAILURE_TARGET_PROFILE|'||current_setting('sitaa.target_profile_outcome');
commit;`;
}

function postcheckSql(targetId, targetEmail, adminAId, adminBId) {
  const target = sqlUuid(targetId);
  const email = sqlText(targetEmail);
  const adminA = sqlUuid(adminAId);
  const adminB = sqlUuid(adminBId);
  const names = sqlText(TARGET_FIRST_NAMES);
  return `
begin;
set transaction read only;
select concat_ws('|','FAILURE_TARGET_POSTCHECK',
  (select count(*) from auth.users),(select count(*) from auth.identities),
  (select count(*) from public.profiles),(select count(*) from public.role_assignments),
  (select count(*) from public.profiles p where p.id in (${adminA},${adminB}) and p.account_status='active'
    and p.is_active and public.is_exact_b1_account_admin_profile_b2b(p.id)),
  (select count(*) from auth.users where id=${target} and lower(email)=${email}
    and email_confirmed_at is not null and banned_until is null
    and raw_app_meta_data->>'provider'='email' and raw_app_meta_data->'providers'='["email"]'::jsonb
    and raw_app_meta_data->>'sitaa_account_kind'='technical' and raw_app_meta_data->>'sitaa_first_names'=${names}),
  (select count(*) from auth.identities where user_id=${target} and provider='email' and lower(identity_data->>'email')=${email}),
  (select count(*) from public.profiles where id=${target} and lower(email)=${email}
    and first_names=${names} and paternal_surname is null and maternal_surname is null and full_name=${names}
    and person_type is null and primary_program_id is null and institutional_id_type is null
    and institutional_id_value is null and account_kind='technical' and account_status='active'
    and is_active and activated_at is not null and deactivated_at is null),
  (select count(*) from public.role_assignments where user_id=${target}),
  (select count(*) from public.admin_auth_operations),
  (select count(*) from public.admin_auth_operations where status='succeeded' and completed_stage='completed'),
  (select count(*) from public.admin_auth_operations where target_profile_id=${target}),
  (select count(*) from public.admin_audit_events where action_code in
    ('account_deactivated','account_reactivated','account_auth_suspended','account_auth_restored','account_auth_suspension_failed','account_auth_restoration_failed')),
  md5(pg_get_functiondef('${HANDLER_SIGNATURE}'::regprocedure)),
  (select count(*) from pg_trigger t where t.tgrelid='auth.users'::regclass and not t.tgisinternal),
  case when ${exactAuthUsersTriggerContractSql()} then 2 else 0 end
);
rollback;`;
}

function assertPostcheck(parts) {
  requireCondition(parts.length === 17 && parts[0] === "FAILURE_TARGET_POSTCHECK", "postcheck_shape_rejected");
  requireCondition(
    parts.slice(1).join("|") === `3|3|3|2|2|1|1|1|0|2|2|0|4|${EXPECTED_HANDLER_MD5}|2|2`,
    "postcheck_state_rejected",
  );
}

async function signInAndVerify(projectUrl, publicKey, email, password, targetId) {
  const client = createClient(projectUrl, publicKey);
  const signedIn = await client.auth.signInWithPassword({ email, password });
  requireCondition(!signedIn.error && signedIn.data?.user?.id === targetId && signedIn.data?.session, "target_login_failed");
  const checked = await client.auth.getUser(signedIn.data.session.access_token);
  requireCondition(!checked.error && checked.data?.user?.id === targetId, "target_get_user_failed");
  await client.auth.signOut({ scope: "local" });
}

function approvedEvidencePairContents() {
  return Object.freeze({
    bootstrap: assertSafeEvidence([
      `HARNESS_VERSION|${VERSION}`,
      "HANDLER_SNAPSHOT|CAPTURED",
      "AUTH_HANDLER_STATE|TARGET_BOOTSTRAP_GATE",
      "AUTH_USER_INVENTORY|EXACTLY_ONE",
      "AUTH_HANDLER_STATE|CANONICAL",
      "FAILURE_TARGET_BOOTSTRAP|APPROVED",
    ].join("\n")),
    postcheck: assertSafeEvidence([
      `HARNESS_VERSION|${VERSION}`,
      "FAILURE_TARGET_AUTH_CONTRACT|APPROVED",
      "FAILURE_TARGET_PROFILE_CONTRACT|APPROVED",
      "FAILURE_TARGET_ASSIGNMENTS|0",
      "AUTH_HANDLER_STATE|CANONICAL",
      "READ_ONLY_TRANSACTION|true",
      "ROLLBACK|true",
    ].join("\n")),
  });
}

function evidenceJournalPaths(bootstrapPath, postcheckPath) {
  return Object.freeze({
    bootstrapPath,
    bootstrapNext: bootstrapPath.replace(/\.local\.txt$/, ".next.local.txt"),
    postcheckPath,
    postcheckNext: postcheckPath.replace(/\.local\.txt$/, ".next.local.txt"),
  });
}

function exactEvidenceFileState(filePath, expectedContents) {
  if (!fs.existsSync(filePath)) return "absent";
  return fs.readFileSync(filePath, "utf8") === expectedContents ? "exact" : "invalid";
}

function inspectApprovedEvidencePair(bootstrapPath, postcheckPath) {
  const journal = evidenceJournalPaths(bootstrapPath, postcheckPath);
  const expected = approvedEvidencePairContents();
  const states = Object.freeze({
    bootstrap: exactEvidenceFileState(journal.bootstrapPath, expected.bootstrap),
    bootstrapNext: exactEvidenceFileState(journal.bootstrapNext, expected.bootstrap),
    postcheck: exactEvidenceFileState(journal.postcheckPath, expected.postcheck),
    postcheckNext: exactEvidenceFileState(journal.postcheckNext, expected.postcheck),
  });
  requireCondition(
    states.bootstrap !== "invalid" && states.postcheck !== "invalid"
      && (states.bootstrap === "exact" || states.bootstrapNext !== "invalid")
      && (states.postcheck === "exact" || states.postcheckNext !== "invalid"),
    "bootstrap_evidence_invalid",
  );
  const bootstrapAvailable = states.bootstrap === "exact" || states.bootstrapNext === "exact";
  const postcheckAvailable = states.postcheck === "exact" || states.postcheckNext === "exact";
  const state = bootstrapAvailable && postcheckAvailable
    ? "complete"
    : bootstrapAvailable || postcheckAvailable ? "partial" : "absent";
  return Object.freeze({ state, states, journal, expected });
}

function promoteOrWriteEvidence(currentPath, nextPath, currentState, nextState, expectedContents) {
  if (currentState === "exact") {
    removeIfExists(nextPath);
    return;
  }
  if (nextState === "exact") {
    fs.renameSync(nextPath, currentPath);
    return;
  }
  requireCondition(nextState === "absent", "bootstrap_evidence_invalid");
  fs.writeFileSync(nextPath, expectedContents, { encoding: "utf8", flag: "wx" });
  requireCondition(exactEvidenceFileState(nextPath, expectedContents) === "exact", "bootstrap_evidence_write_rejected");
  fs.renameSync(nextPath, currentPath);
}

function publishApprovedEvidencePair(bootstrapPath, postcheckPath, interruptAt = null) {
  let inspection = inspectApprovedEvidencePair(bootstrapPath, postcheckPath);
  const { journal, expected } = inspection;
  if (inspection.states.bootstrap === "absent" && inspection.states.bootstrapNext === "absent") {
    fs.writeFileSync(journal.bootstrapNext, expected.bootstrap, { encoding: "utf8", flag: "wx" });
    if (interruptAt === "after_bootstrap_next") throw new Error("fixture_interrupt_after_bootstrap_next");
    inspection = inspectApprovedEvidencePair(bootstrapPath, postcheckPath);
  }
  promoteOrWriteEvidence(
    journal.bootstrapPath,
    journal.bootstrapNext,
    inspection.states.bootstrap,
    inspection.states.bootstrapNext,
    expected.bootstrap,
  );
  if (interruptAt === "after_bootstrap") throw new Error("fixture_interrupt_after_bootstrap");
  inspection = inspectApprovedEvidencePair(bootstrapPath, postcheckPath);
  if (inspection.states.postcheck === "absent" && inspection.states.postcheckNext === "absent") {
    fs.writeFileSync(journal.postcheckNext, expected.postcheck, { encoding: "utf8", flag: "wx" });
    if (interruptAt === "after_postcheck_next") throw new Error("fixture_interrupt_after_postcheck_next");
    inspection = inspectApprovedEvidencePair(bootstrapPath, postcheckPath);
  }
  promoteOrWriteEvidence(
    journal.postcheckPath,
    journal.postcheckNext,
    inspection.states.postcheck,
    inspection.states.postcheckNext,
    expected.postcheck,
  );
  if (interruptAt === "after_postcheck") throw new Error("fixture_interrupt_after_postcheck");
  inspection = inspectApprovedEvidencePair(bootstrapPath, postcheckPath);
  requireCondition(inspection.state === "complete", "bootstrap_evidence_pair_incomplete");
  removeIfExists(journal.bootstrapNext);
  removeIfExists(journal.postcheckNext);
  return inspection;
}

function removeRepairArtifacts(repairPath, snapshotPath) {
  const journal = bundleJournalPaths(repairPath, snapshotPath);
  for (const filePath of Object.values(journal)) {
    if (fs.existsSync(filePath)) fs.unlinkSync(filePath);
    requireCondition(!fs.existsSync(filePath), "repair_cleanup_required");
  }
}

function postSuccessCleanupPaths(repairPath, snapshotPath, evidencePath, postcheckPath) {
  const bundle = bundleJournalPaths(repairPath, snapshotPath);
  const evidence = evidenceJournalPaths(evidencePath, postcheckPath);
  return Object.freeze([
    ...Object.values(bundle),
    evidence.bootstrapNext,
    evidence.postcheckNext,
  ]);
}

function cleanupApprovedProvisioningArtifacts({
  repairPath,
  snapshotPath,
  evidencePath,
  postcheckPath,
  evidenceState,
  remotePostcheckApproved,
  unlinkFile = fs.unlinkSync,
}) {
  requireCondition(
    (evidenceState === "complete" || evidenceState === "partial")
      && remotePostcheckApproved === true,
    "post_success_cleanup_not_authorized",
  );
  const cleanupPaths = postSuccessCleanupPaths(
    repairPath,
    snapshotPath,
    evidencePath,
    postcheckPath,
  );
  let cleanupFailed = false;
  for (const filePath of cleanupPaths) {
    if (!fs.existsSync(filePath)) continue;
    try {
      unlinkFile(filePath);
    } catch {
      cleanupFailed = true;
    }
  }
  const remaining = cleanupPaths.filter((filePath) => fs.existsSync(filePath));
  requireCondition(!cleanupFailed && remaining.length === 0, "repair_cleanup_required");
}

function hasRepairArtifacts(repairPath, snapshotPath) {
  return Object.values(bundleJournalPaths(repairPath, snapshotPath)).some((filePath) => fs.existsSync(filePath));
}

async function collectSecrets(repoRoot) {
  const supabaseJsVersion = await loadSupabaseJs(repoRoot);
  const projectUrl = (await readMasked("Project URL exacta: ")).trim();
  const publicKey = validatePublicApiKey((await readMasked("Publishable/anon key: ")).trim());
  const serviceKey = validatePrivilegedApiKey((await readMasked("Service role/secret key: ")).trim());
  const targetPassword = await readMasked("Contraseña de Target C: ");
  requireCondition(projectUrl === EXPECTED_PROJECT_URL, "project_url_rejected");
  requireCondition(targetPassword.length >= 16, "target_password_rejected");
  return { supabaseJsVersion, projectUrl, publicKey, serviceKey, targetPassword };
}

async function collectAbandonSecrets(repoRoot) {
  const supabaseJsVersion = await loadSupabaseJs(repoRoot);
  const projectUrl = (await readMasked("Project URL exacta: ")).trim();
  const serviceKey = validatePrivilegedApiKey((await readMasked("Service role/secret key: ")).trim());
  requireCondition(projectUrl === EXPECTED_PROJECT_URL, "project_url_rejected");
  return { supabaseJsVersion, projectUrl, serviceKey };
}

function targetUsers(users) {
  requireCondition(Array.isArray(users), "target_inventory_invalid");
  return users.filter((user) => TARGET_EMAIL_PATTERN.test(String(user.email ?? "").toLowerCase()));
}

async function authAdminBootstrapPreflight(serviceClient, knownUsers = null) {
  const users = knownUsers ?? await listAllAuthUsers(serviceClient);
  requireCondition(users.length === 2 && targetUsers(users).length === 0, "auth_admin_bootstrap_preflight_rejected");
  console.log("AUTH_ADMIN_BOOTSTRAP_PREFLIGHT|APPROVED");
  return users;
}

async function publishableKeyBootstrapPreflight(publicClient) {
  let result;
  try {
    result = await publicClient
      .from("system_health")
      .select("status")
      .limit(1);
  } catch (error) {
    fail(authRequestFailureCode(error, "publishable_key_bootstrap_preflight_rejected"));
  }
  if (result?.error) {
    fail(authRequestFailureCode(result.error, "publishable_key_bootstrap_preflight_rejected"));
  }
  requireCondition(
    Array.isArray(result?.data) && result.data.length <= 1,
    "system_health_response_malformed",
  );
  if (result.data.length === 1) {
    const row = result.data[0];
    requireCondition(
      row && typeof row === "object" && !Array.isArray(row)
        && Object.keys(row).length === 1
        && Object.hasOwn(row, "status")
        && typeof row.status === "string",
      "system_health_response_malformed",
    );
    requireCondition(row.status === "ok", "system_health_not_ok");
  }
  console.log("PUBLISHABLE_KEY_BOOTSTRAP_PREFLIGHT|APPROVED");
}

async function attemptCreateAuthTarget(serviceClient, email, password) {
  try {
    const response = await serviceClient.auth.admin.createUser({
      email,
      password,
      email_confirm: true,
      app_metadata: {
        sitaa_account_kind: "technical",
        sitaa_first_names: TARGET_FIRST_NAMES,
      },
    });
    return response.error
      ? { succeeded: false, errorCode: classifyCreateError(response.error) }
      : { succeeded: true, errorCode: null };
  } catch (error) {
    return { succeeded: false, errorCode: classifyCreateError(error) };
  }
}

async function resolveCreatedTargetAfterRestore(serviceClient, email, attempt) {
  requireCondition(!authHandlerGateActive, "handler_must_be_restored_before_inventory");
  const users = await listAllAuthUsers(serviceClient);
  const matches = users.filter((user) => String(user.email ?? "").toLowerCase() === email);
  const outcome = resolveCreateOutcome({ attempt, matches });
  requireCondition(
    UUID_PATTERN.test(outcome.user.id) && outcome.user.email_confirmed_at && !outcome.user.banned_until
      && outcome.user.app_metadata?.sitaa_account_kind === "technical"
      && outcome.user.app_metadata?.sitaa_first_names === TARGET_FIRST_NAMES,
    "target_auth_contract_rejected",
  );
  if (outcome.classification === "response_lost_target_present") {
    console.log("AUTH_CREATE_RESULT|response_lost_target_present");
  } else {
    console.log("AUTH_CREATE_RESULT|created");
  }
  return outcome;
}

function classifyResumeTargets(users, repair) {
  const targets = targetUsers(users);
  if (targets.length > 1) fail("resume_target_inventory_duplicated");
  if (targets.length === 0) {
    requireCondition(users.length === 2 && repair.target_uuid === null, "resume_zero_target_inventory_rejected");
    return { state: "zero", user: null };
  }
  requireCondition(
    users.length === 3 && String(targets[0].email ?? "").toLowerCase() === repair.target_email,
    "resume_target_inventory_rejected",
  );
  const user = targets[0];
  requireCondition(
    UUID_PATTERN.test(user.id) && (!repair.target_uuid || repair.target_uuid === user.id)
      && user.email_confirmed_at && !user.banned_until
      && user.app_metadata?.sitaa_account_kind === "technical"
      && user.app_metadata?.sitaa_first_names === TARGET_FIRST_NAMES,
    "resume_target_auth_contract_rejected",
  );
  return { state: "one", user };
}

function classifyFinalizationTarget(users) {
  const targets = targetUsers(users);
  requireCondition(
    users.length === 3 && targets.length === 1,
    targets.length > 1
      ? "finalization_target_inventory_duplicated"
      : "finalization_target_inventory_rejected",
  );
  const user = targets[0];
  requireCondition(
    UUID_PATTERN.test(user.id)
      && TARGET_EMAIL_PATTERN.test(String(user.email ?? "").toLowerCase())
      && user.email_confirmed_at
      && !user.banned_until
      && user.app_metadata?.sitaa_account_kind === "technical"
      && user.app_metadata?.sitaa_first_names === TARGET_FIRST_NAMES,
    "finalization_target_auth_contract_rejected",
  );
  return user;
}

function handlerStateSql() {
  return `
begin;
set transaction read only;
select concat_ws('|','AUTH_HANDLER_STATE_CHECK',md5(pg_get_functiondef('${HANDLER_SIGNATURE}'::regprocedure)),
  case when position('sitaa_target_bootstrap_email_not_allowed' in pg_get_functiondef('${HANDLER_SIGNATURE}'::regprocedure))>0 then 1 else 0 end,
  case when ${exactAuthUsersTriggerContractSql()} then 1 else 0 end);
rollback;`;
}

function isHandlerCanonical(parts) {
  requireCondition(parts.length === 4 && parts[0] === "AUTH_HANDLER_STATE_CHECK", "handler_state_shape_rejected");
  return parts[1] === EXPECTED_HANDLER_MD5 && parts[2] === "0" && parts[3] === "1";
}

function assertRepairMatchesCanonicalHandler(repair, canonical, options = {}) {
  requireCondition(
    canonical.oid === repair.original_oid
      && canonical.acl === repairAcl(repair, options)
      && canonical.md5 === repair.original_md5,
    "resume_handler_contract_rejected",
  );
}

async function createWithinTemporaryHandlerGate({
  connection,
  serviceClient,
  repairPath,
  snapshotPath,
  repair,
  capture,
  targetPassword,
  repairOptions = {},
}) {
  let attempt = null;
  let restorationRequired = false;
  try {
    restorationRequired = true;
    authHandlerGateActive = true;
    const gate = executeControlledMutation(
      connection,
      handlerGateSql(repair.target_email, capture),
      "AUTH_HANDLER_GATE",
      "handler_gate",
    );
    requireCondition(gate.length === 2 && gate[1] === "1", "handler_gate_result_rejected");
    updateRepair(repairPath, snapshotPath, { phase: "handler_gate_open" }, null, repairOptions);
    console.log("AUTH_HANDLER_STATE|TARGET_BOOTSTRAP_GATE");
    attempt = await attemptCreateAuthTarget(serviceClient, repair.target_email, targetPassword);
  } finally {
    if (restorationRequired) {
      restoreHandler(connection, repairPath, snapshotPath, repairOptions);
      authHandlerGateActive = false;
      restorationRequired = false;
    }
  }
  requireCondition(attempt !== null, "target_creation_failed");
  const outcome = await resolveCreatedTargetAfterRestore(
    serviceClient,
    repair.target_email,
    attempt,
  );
  updateRepair(repairPath, snapshotPath, {
    target_uuid: outcome.user.id,
    phase: outcome.classification === "response_lost_target_present"
      ? "auth_response_lost_target_present"
      : "auth_user_created",
  }, null, repairOptions);
  return outcome.user;
}

async function completeProvisioning({
  repoRoot,
  connection,
  repairPath,
  snapshotPath,
  repair,
  secrets,
  user,
  adminA,
  adminB,
  repairOptions = {},
}) {
  const profileParts = executeControlledMutation(
    connection,
    profileProvisionSql(user.id, repair.target_email),
    "FAILURE_TARGET_PROFILE",
    "profile",
  );
  requireCondition(profileParts.length === 2 && ["created", "replayed"].includes(profileParts[1]), "profile_result_rejected");
  updateRepair(repairPath, snapshotPath, {
    target_uuid: user.id,
    phase: profileParts[1] === "created" ? "profile_created" : "profile_replayed",
  }, null, repairOptions);
  await signInAndVerify(secrets.projectUrl, secrets.publicKey, repair.target_email, secrets.targetPassword, user.id);
  const postcheck = executeReadOnlySql(
    connection,
    postcheckSql(user.id, repair.target_email, adminA.id, adminB.id),
    "FAILURE_TARGET_POSTCHECK",
  );
  assertPostcheck(postcheck);
  const evidencePath = path.join(path.dirname(repairPath), "b3a_matrix_failure_recovery_target_bootstrap.local.txt");
  const postcheckPath = path.join(path.dirname(repairPath), "b3a_matrix_failure_recovery_target_bootstrap_postcheck.local.txt");
  publishApprovedEvidencePair(evidencePath, postcheckPath);
  cleanupApprovedProvisioningArtifacts({
    repairPath,
    snapshotPath,
    evidencePath,
    postcheckPath,
    evidenceState: "complete",
    remotePostcheckApproved: true,
  });
  console.log("FAILURE_TARGET_BOOTSTRAP|APPROVED");
  console.log("FAILURE_TARGET_AUTH_CONTRACT|APPROVED");
  console.log("FAILURE_TARGET_PROFILE_CONTRACT|APPROVED");
  console.log("FAILURE_TARGET_ASSIGNMENTS|0");
  console.log("AUTH_HANDLER_STATE|CANONICAL");
  console.log("READ_ONLY_TRANSACTION|true");
  console.log("ROLLBACK|true");
  void repoRoot;
}

async function finalizeProvisioningReadOnly({
  connection,
  repairPath,
  snapshotPath,
  evidencePath,
  postcheckPath,
  secrets,
  adminA,
  adminB,
}) {
  const evidence = inspectApprovedEvidencePair(evidencePath, postcheckPath);
  requireCondition(evidence.state === "complete" || evidence.state === "partial", "bootstrap_evidence_missing");
  const handlerState = executeReadOnlySql(connection, handlerStateSql(), "AUTH_HANDLER_STATE_CHECK");
  requireCondition(isHandlerCanonical(handlerState), "finalization_handler_not_canonical");
  parseHandlerCapture(
    executeReadOnlySql(connection, handlerCaptureSql(), "AUTH_HANDLER_CAPTURE"),
  );
  const serviceClient = createClient(secrets.projectUrl, secrets.serviceKey);
  const users = await listAllAuthUsers(serviceClient);
  const target = classifyFinalizationTarget(users);
  const postcheck = executeReadOnlySql(
    connection,
    postcheckSql(target.id, String(target.email).toLowerCase(), adminA.id, adminB.id),
    "FAILURE_TARGET_POSTCHECK",
  );
  assertPostcheck(postcheck);
  const remotePostcheckApproved = true;
  try {
    publishApprovedEvidencePair(evidencePath, postcheckPath);
  } catch (error) {
    if (error instanceof SafeFailure) throw error;
    fail("repair_cleanup_required");
  }
  requireCondition(inspectApprovedEvidencePair(evidencePath, postcheckPath).state === "complete", "bootstrap_evidence_pair_incomplete");
  cleanupApprovedProvisioningArtifacts({
    repairPath,
    snapshotPath,
    evidencePath,
    postcheckPath,
    evidenceState: evidence.state,
    remotePostcheckApproved,
  });
  requireCondition(
    postSuccessCleanupPaths(repairPath, snapshotPath, evidencePath, postcheckPath)
      .every((filePath) => !fs.existsSync(filePath)),
    "repair_cleanup_required",
  );
  console.log("FAILURE_TARGET_PROVISIONING_FINALIZATION|APPROVED");
  console.log("AUTH_HANDLER_STATE|CANONICAL");
  console.log("REPAIR_BUNDLE|ABSENT");
}

async function normalMain({ resume = false } = {}) {
  const repoRoot = path.resolve(process.env.SITAA_B3A_REPO_ROOT ?? "");
  requireCondition(repoRoot && process.cwd() === repoRoot, "repository_root_required");
  requireCondition(process.env.SITAA_B3A_PROJECT_REF === EXPECTED_PROJECT_REF, "project_ref_rejected");
  const fixtures = loadAdminFixtures(repoRoot);
  const adminA = fixtures.get("admin_a");
  const adminB = fixtures.get("admin_b");
  const reconciliationRoot = path.join(repoRoot, "supabase", "reconciliation");
  const repairPath = path.join(reconciliationRoot, "b3a_matrix_failure_recovery_target_handler_repair.local.json");
  const snapshotPath = path.join(reconciliationRoot, "b3a_matrix_failure_recovery_target_handler_snapshot.local.sql");
  const evidencePath = path.join(reconciliationRoot, "b3a_matrix_failure_recovery_target_bootstrap.local.txt");
  const postcheckPath = path.join(reconciliationRoot, "b3a_matrix_failure_recovery_target_bootstrap_postcheck.local.txt");
  const evidenceState = inspectApprovedEvidencePair(evidencePath, postcheckPath);
  const connection = parsePostgresConnectionUri(process.env.SITAA_B3A_DB_URL ?? "");

  if (resume) {
    if (evidenceState.state !== "absent") {
      const secrets = await collectAbandonSecrets(repoRoot);
      await finalizeProvisioningReadOnly({
        connection, repairPath, snapshotPath, evidencePath, postcheckPath,
        secrets, adminA, adminB,
      });
      return;
    }
    let repair = readRepair(repairPath, snapshotPath, RECOVERABLE_REPAIR_OPTIONS);
    if (repair.version === RECOVERABLE_PREDECESSOR_VERSION) {
      console.log("RECOVERABLE_PREDECESSOR_BUNDLE|v6|APPROVED");
    }
    const state = executeReadOnlySql(connection, handlerStateSql(), "AUTH_HANDLER_STATE_CHECK");
    if (!isHandlerCanonical(state)) {
      restoreHandler(connection, repairPath, snapshotPath, RECOVERABLE_REPAIR_OPTIONS);
      authHandlerGateActive = false;
      repair = readRepair(repairPath, snapshotPath, RECOVERABLE_REPAIR_OPTIONS);
    }
    const canonical = parseHandlerCapture(
      executeReadOnlySql(connection, handlerCaptureSql(), "AUTH_HANDLER_CAPTURE"),
    );
    assertRepairMatchesCanonicalHandler(repair, canonical, RECOVERABLE_REPAIR_OPTIONS);
    const secrets = await collectSecrets(repoRoot);
    const serviceClient = createClient(secrets.projectUrl, secrets.serviceKey);
    const users = await listAllAuthUsers(serviceClient);
    const resumeState = classifyResumeTargets(users, repair);
    let user = resumeState.user;
    if (resumeState.state === "zero") {
      assertBaseline(executeReadOnlySql(
        connection,
        baselineSql(adminA.id, adminB.id),
        "FAILURE_TARGET_BOOTSTRAP_BASELINE",
      ));
      await authAdminBootstrapPreflight(serviceClient, users);
      const publicClient = createClient(secrets.projectUrl, secrets.publicKey);
      await publishableKeyBootstrapPreflight(publicClient);
      console.log("Escribe RETRY_FAILURE_TARGET_CREATION para reintentar la creación.");
      if (!await readConfirmation("RETRY_FAILURE_TARGET_CREATION")) {
        console.log("FAILURE_TARGET_BOOTSTRAP|ABORTED");
        process.exitCode = OPERATOR_ABORT_EXIT_CODE;
        return;
      }
      user = await createWithinTemporaryHandlerGate({
        connection,
        serviceClient,
        repairPath,
        snapshotPath,
        repair,
        capture: canonical,
        targetPassword: secrets.targetPassword,
        repairOptions: RECOVERABLE_REPAIR_OPTIONS,
      });
      repair = readRepair(repairPath, snapshotPath, RECOVERABLE_REPAIR_OPTIONS);
    } else {
      const resumePrecheck = executeReadOnlySql(
        connection,
        resumeProvisioningPrecheckSql(user.id, repair.target_email, adminA.id, adminB.id),
        "FAILURE_TARGET_RESUME_PRECHECK",
      );
      assertResumeProvisioningPrecheck(resumePrecheck);
      console.log("Escribe RESUME_FAILURE_TARGET_PROVISIONING para completar el perfil existente.");
      if (!await readConfirmation("RESUME_FAILURE_TARGET_PROVISIONING")) {
        console.log("FAILURE_TARGET_BOOTSTRAP|ABORTED");
        process.exitCode = OPERATOR_ABORT_EXIT_CODE;
        return;
      }
    }
    requireCondition(user !== null, "resume_target_inventory_rejected");
    await completeProvisioning({
      repoRoot,
      connection,
      repairPath,
      snapshotPath,
      repair,
      secrets,
      user,
      adminA,
      adminB,
      repairOptions: RECOVERABLE_REPAIR_OPTIONS,
    });
    return;
  }

  requireCondition(evidenceState.state === "absent", "bootstrap_evidence_exists");
  requireCondition(recoverRepairBundle(repairPath, snapshotPath) === "absent", "handler_repair_file_exists");
  assertBaseline(executeReadOnlySql(
    connection,
    baselineSql(adminA.id, adminB.id),
    "FAILURE_TARGET_BOOTSTRAP_BASELINE",
  ));
  const secrets = await collectSecrets(repoRoot);
  const serviceClient = createClient(secrets.projectUrl, secrets.serviceKey);
  await authAdminBootstrapPreflight(serviceClient);
  const publicClient = createClient(secrets.projectUrl, secrets.publicKey);
  await publishableKeyBootstrapPreflight(publicClient);
  console.log("Escribe OPEN_FAILURE_TARGET_BOOTSTRAP_WINDOW para continuar.");
  if (!await readConfirmation("OPEN_FAILURE_TARGET_BOOTSTRAP_WINDOW")) {
    console.log("FAILURE_TARGET_BOOTSTRAP|ABORTED");
    process.exitCode = OPERATOR_ABORT_EXIT_CODE;
    return;
  }

  const targetEmail = generateTargetEmail();
  const capture = parseHandlerCapture(executeReadOnlySql(connection, handlerCaptureSql(), "AUTH_HANDLER_CAPTURE"));
  let repair = publishRepairBundle(repairPath, snapshotPath, {
    version: VERSION,
    target_email: targetEmail,
    target_uuid: null,
    original_oid: capture.oid,
    original_acl_base64: Buffer.from(capture.acl, "utf8").toString("base64"),
    original_md5: capture.md5,
    snapshot_relative_path: "supabase/reconciliation/b3a_matrix_failure_recovery_target_handler_snapshot.local.sql",
    phase: "handler_captured",
  }, capture.definition);
  const user = await createWithinTemporaryHandlerGate({
    connection,
    serviceClient,
    repairPath,
    snapshotPath,
    repair,
    capture,
    targetPassword: secrets.targetPassword,
  });
  repair = readRepair(repairPath, snapshotPath);
  await completeProvisioning({
    repoRoot, connection, repairPath, snapshotPath, repair, secrets, user, adminA, adminB,
  });
}

async function finalizeProvisioningMain() {
  const repoRoot = path.resolve(process.env.SITAA_B3A_REPO_ROOT ?? "");
  requireCondition(repoRoot && process.cwd() === repoRoot, "repository_root_required");
  requireCondition(process.env.SITAA_B3A_PROJECT_REF === EXPECTED_PROJECT_REF, "project_ref_rejected");
  const fixtures = loadAdminFixtures(repoRoot);
  const adminA = fixtures.get("admin_a");
  const adminB = fixtures.get("admin_b");
  const reconciliationRoot = path.join(repoRoot, "supabase", "reconciliation");
  const repairPath = path.join(reconciliationRoot, "b3a_matrix_failure_recovery_target_handler_repair.local.json");
  const snapshotPath = path.join(reconciliationRoot, "b3a_matrix_failure_recovery_target_handler_snapshot.local.sql");
  const evidencePath = path.join(reconciliationRoot, "b3a_matrix_failure_recovery_target_bootstrap.local.txt");
  const postcheckPath = path.join(reconciliationRoot, "b3a_matrix_failure_recovery_target_bootstrap_postcheck.local.txt");
  const evidence = inspectApprovedEvidencePair(evidencePath, postcheckPath);
  requireCondition(evidence.state === "complete" || evidence.state === "partial", "bootstrap_evidence_missing");
  const connection = parsePostgresConnectionUri(process.env.SITAA_B3A_DB_URL ?? "");
  const secrets = await collectAbandonSecrets(repoRoot);
  await finalizeProvisioningReadOnly({
    connection, repairPath, snapshotPath, evidencePath, postcheckPath,
    secrets, adminA, adminB,
  });
}

async function restoreOnlyMain() {
  const repoRoot = path.resolve(process.env.SITAA_B3A_REPO_ROOT ?? "");
  requireCondition(repoRoot && process.cwd() === repoRoot, "repository_root_required");
  requireCondition(process.env.SITAA_B3A_PROJECT_REF === EXPECTED_PROJECT_REF, "project_ref_rejected");
  const reconciliationRoot = path.join(repoRoot, "supabase", "reconciliation");
  const repairPath = path.join(reconciliationRoot, "b3a_matrix_failure_recovery_target_handler_repair.local.json");
  const snapshotPath = path.join(reconciliationRoot, "b3a_matrix_failure_recovery_target_handler_snapshot.local.sql");
  const repair = readRepair(repairPath, snapshotPath, RECOVERABLE_REPAIR_OPTIONS);
  if (repair.version === RECOVERABLE_PREDECESSOR_VERSION) {
    console.log("RECOVERABLE_PREDECESSOR_BUNDLE|v6|APPROVED");
  }
  const connection = parsePostgresConnectionUri(process.env.SITAA_B3A_DB_URL ?? "");
  console.log("Escribe OPEN_FAILURE_TARGET_BOOTSTRAP_WINDOW para restaurar el handler.");
  if (!await readConfirmation("OPEN_FAILURE_TARGET_BOOTSTRAP_WINDOW")) {
    console.log("AUTH_HANDLER_RESTORE|ABORTED");
    process.exitCode = OPERATOR_ABORT_EXIT_CODE;
    return;
  }
  restoreHandler(connection, repairPath, snapshotPath, RECOVERABLE_REPAIR_OPTIONS);
  authHandlerGateActive = false;
}

async function abandonProvisioningMain() {
  const repoRoot = path.resolve(process.env.SITAA_B3A_REPO_ROOT ?? "");
  requireCondition(repoRoot && process.cwd() === repoRoot, "repository_root_required");
  requireCondition(process.env.SITAA_B3A_PROJECT_REF === EXPECTED_PROJECT_REF, "project_ref_rejected");
  const fixtures = loadAdminFixtures(repoRoot);
  const adminA = fixtures.get("admin_a");
  const adminB = fixtures.get("admin_b");
  const reconciliationRoot = path.join(repoRoot, "supabase", "reconciliation");
  const repairPath = path.join(reconciliationRoot, "b3a_matrix_failure_recovery_target_handler_repair.local.json");
  const snapshotPath = path.join(reconciliationRoot, "b3a_matrix_failure_recovery_target_handler_snapshot.local.sql");
  const repair = readRepair(repairPath, snapshotPath, RECOVERABLE_REPAIR_OPTIONS);
  if (repair.version === RECOVERABLE_PREDECESSOR_VERSION) {
    console.log("RECOVERABLE_PREDECESSOR_BUNDLE|v6|APPROVED");
  }
  const connection = parsePostgresConnectionUri(process.env.SITAA_B3A_DB_URL ?? "");
  const state = executeReadOnlySql(connection, handlerStateSql(), "AUTH_HANDLER_STATE_CHECK");
  requireCondition(isHandlerCanonical(state), "abandon_handler_not_canonical");
  const canonical = parseHandlerCapture(
    executeReadOnlySql(connection, handlerCaptureSql(), "AUTH_HANDLER_CAPTURE"),
  );
  assertRepairMatchesCanonicalHandler(repair, canonical, RECOVERABLE_REPAIR_OPTIONS);
  assertBaseline(executeReadOnlySql(
    connection,
    baselineSql(adminA.id, adminB.id),
    "FAILURE_TARGET_BOOTSTRAP_BASELINE",
  ));
  const secrets = await collectAbandonSecrets(repoRoot);
  const serviceClient = createClient(secrets.projectUrl, secrets.serviceKey);
  await authAdminBootstrapPreflight(serviceClient);
  console.log("Escribe ABANDON_FAILURE_TARGET_PROVISIONING para eliminar el bundle local.");
  if (!await readConfirmation("ABANDON_FAILURE_TARGET_PROVISIONING")) {
    console.log("FAILURE_TARGET_ABANDON|ABORTED");
    process.exitCode = OPERATOR_ABORT_EXIT_CODE;
    return;
  }
  removeRepairArtifacts(repairPath, snapshotPath);
  console.log("FAILURE_TARGET_ABANDON|APPROVED");
}

async function readOnlyProbeMain() {
  const repoRoot = path.resolve(process.env.SITAA_B3A_REPO_ROOT ?? "");
  requireCondition(repoRoot && process.cwd() === repoRoot, "repository_root_required");
  requireCondition(process.env.SITAA_B3A_PROJECT_REF === EXPECTED_PROJECT_REF, "project_ref_rejected");
  const fixtures = loadAdminFixtures(repoRoot);
  const connection = parsePostgresConnectionUri(process.env.SITAA_B3A_DB_URL ?? "");
  assertBaseline(executeReadOnlySql(
    connection,
    baselineSql(fixtures.get("admin_a").id, fixtures.get("admin_b").id),
    "FAILURE_TARGET_BOOTSTRAP_BASELINE",
  ));
  console.log("READ_ONLY_TRANSACTION|true");
  console.log("ROLLBACK|true");
}

async function runSelfTests(repoRoot) {
  assertLocalRepairJsonGitignore(repoRoot);
  requireCondition(readSupabaseJsVersion(repoRoot) === EXPECTED_SUPABASE_JS_VERSION, "dependency_fixture_rejected");
  const adminA = "11111111-1111-4111-8111-111111111111";
  const adminB = "22222222-2222-4222-8222-222222222222";
  const target = "33333333-3333-4333-8333-333333333333";
  const email = "b3a-failure-target-20260803123456789-abcdefabcdef@example.invalid";
  const metadata = {
    oid: "12345",
    acl: EXPECTED_HANDLER_ACL,
    md5: EXPECTED_HANDLER_MD5,
  };
  const expectSafeFailure = (callback, expectedCode) => {
    let rejected = false;
    try {
      callback();
    } catch (error) {
      rejected = error instanceof SafeFailure && error.code === expectedCode;
    }
    requireCondition(rejected, `expected_${expectedCode}_fixture_rejected`);
  };
  const expectSafeFailureAsync = async (callback, expectedCode) => {
    let rejected = false;
    try {
      await callback();
    } catch (error) {
      rejected = error instanceof SafeFailure && error.code === expectedCode;
    }
    requireCondition(rejected, `expected_${expectedCode}_fixture_rejected`);
  };
  const baseline = normalizeEol(baselineSql(adminA, adminB)).trim();
  requireCondition(baseline.startsWith("begin;\nset transaction read only;") && baseline.endsWith("rollback;"), "baseline_fixture_rejected");
  requireCondition(
    CURRENT_BOOTSTRAP_VERSION === "2026-08-04-b3a-failure-target-bootstrap-v7"
      && RECOVERABLE_PREDECESSOR_VERSION === "2026-08-04-b3a-failure-target-bootstrap-v6"
      && VERSION === CURRENT_BOOTSTRAP_VERSION
      && TARGET_EMAIL_PATTERN.test(email)
      && !TARGET_EMAIL_PATTERN.test("b3a-failure-target-arbitrary-abcdefabcdef@example.invalid")
      && generateTargetEmail().match(TARGET_EMAIL_PATTERN),
    "version_and_target_pattern_fixture_rejected",
  );
  const gate = handlerGateSql(email, metadata);
  const snapshotDefinition = `CREATE OR REPLACE FUNCTION public.handle_sitaa_auth_user_created()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'pg_catalog', 'public', 'auth'
AS $function$
begin
  return new;
end;
$function$`;
  const terminatedSnapshotDefinition = `${snapshotDefinition};`;
  const restore = handlerRestoreSql(
    snapshotDefinition,
    metadata,
  );
  const restoreFromTerminated = handlerRestoreSql(terminatedSnapshotDefinition, metadata);
  const restoreFromTrailingWhitespace = handlerRestoreSql(
    `${snapshotDefinition.replace(/\n/g, "\r\n")}\r\n  `,
    metadata,
  );
  const selectAssembly = assembleCapturedFunctionSql(
    snapshotDefinition,
    "select 'RESTORE_FIXTURE|1';",
  );
  assertControlledMutation(gate, "handler_gate");
  assertControlledMutation(restore, "handler_restore");
  assertControlledMutation(restoreFromTerminated, "handler_restore");
  assertControlledMutation(restoreFromTrailingWhitespace, "handler_restore");
  expectSafeFailure(
    () => assertCapturedFunctionStatementBoundary(`${snapshotDefinition}\nselect 'RESTORE_FIXTURE|0';`),
    "captured_function_statement_boundary_rejected",
  );
  requireCondition(
    gate.includes("sitaa_target_bootstrap_email_not_allowed")
      && gate.includes("if (select count(*) from auth.users where id<>new.id)<>2")
      && !gate.includes("insert into public.profiles")
      && restore.includes(EXPECTED_HANDLER_MD5)
      && restore.includes(sqlText(EXPECTED_HANDLER_ACL))
      && restore.includes("AUTH_HANDLER_RESTORED|1")
      && ensureSqlStatementTerminated(snapshotDefinition) === terminatedSnapshotDefinition
      && ensureSqlStatementTerminated(terminatedSnapshotDefinition) === terminatedSnapshotDefinition
      && ensureSqlStatementTerminated(`${snapshotDefinition.replace(/\n/g, "\r\n")}\r\n  `) === terminatedSnapshotDefinition
      && restore.includes("$function$;\ndo $verify$")
      && restoreFromTerminated.includes("$function$;\ndo $verify$")
      && restoreFromTrailingWhitespace.includes("$function$;\ndo $verify$")
      && !restore.includes("$function$;;")
      && selectAssembly.includes("$function$;\nselect 'RESTORE_FIXTURE|1';"),
    "handler_gate_restore_fixture_rejected",
  );
  const rejectedRestoreLines = restoreAttemptRejectionLines(
    1,
    new RestoreAttemptFailure("syntax_error"),
  );
  requireCondition(
    classifyRestoreProcessResult({ status: 3, stderr: "ERROR: syntax error at or near SELECT" }) === "syntax_error"
      && classifyRestoreProcessResult({ status: 3, stderr: "ERROR: canceling statement due to lock timeout" }) === "lock_timeout"
      && classifyRestoreProcessResult({ status: 3, stderr: "ERROR: canceling statement due to statement timeout" }) === "statement_timeout"
      && classifyRestoreProcessResult({ status: 3, stderr: "ERROR: permission denied" }) === "permission_rejected"
      && classifyRestoreProcessResult({ status: 3, stderr: "ERROR: sitaa_target_bootstrap_restore_rejected" }) === "restore_contract_rejected"
      && classifyRestoreProcessResult({ status: null, error: { code: "ENOENT" }, stderr: "" }) === "process_unavailable"
      && classifyRestoreProcessResult({ status: 3, stderr: "fixture failure" }) === "unknown_restore_failure"
      && rejectedRestoreLines.length === 2
      && rejectedRestoreLines[0] === "AUTH_HANDLER_RESTORE_ATTEMPT|1|REJECTED"
      && rejectedRestoreLines[1] === "AUTH_HANDLER_RESTORE_DIAGNOSTIC|1|syntax_error"
      && !executeHandlerRestoreMutation.toString().includes("AUTH_HANDLER_RESTORED|STARTED"),
    "restore_diagnostic_classification_fixture_rejected",
  );
  const exactTriggerContract = exactAuthUsersTriggerContractSql();
  requireCondition(
    exactTriggerContract.includes("trigger_definition.tgtype=5::smallint")
      && exactTriggerContract.includes("cardinality(trigger_definition.tgattr::smallint[])=0")
      && exactTriggerContract.includes("trigger_definition.tgqual is null")
      && exactTriggerContract.includes("trigger_definition.tgtype=17::smallint")
      && exactTriggerContract.includes("cardinality(trigger_definition.tgattr::smallint[])=1")
      && exactTriggerContract.includes("attribute_definition.attname='email'")
      && exactTriggerContract.includes("='updateofemail'")
      && exactTriggerContract.includes("='old.emailisdistinctfromnew.email'")
      && exactTriggerContract.includes("not trigger_definition.tgisinternal)=2"),
    "exact_auth_trigger_contract_fixture_rejected",
  );
  for (const sql of [
    baselineSql(adminA, adminB),
    handlerCaptureSql(),
    gate,
    restore,
    postcheckSql(target, email, adminA, adminB),
    handlerStateSql(),
  ]) {
    requireCondition(
      sql.includes(exactTriggerContract),
      "exact_auth_trigger_fixture_rejected",
    );
  }

  const postgresFixtureUri = ({
    projectRef = EXPECTED_PROJECT_REF,
    password = "p%40ssword",
    port = "5432",
    database = "postgres",
    query = "?sslmode=require",
  } = {}) => [
    "postgresql://",
    `postgres.${projectRef}`,
    ":",
    password,
    String.fromCharCode(64),
    "aws-0-us-east-1.pooler.supabase.com:",
    port,
    "/",
    database,
    query,
  ].join("");
  const validUri = postgresFixtureUri();
  const connection = parsePostgresConnectionUri(validUri);
  requireCondition(
    connection.username === `postgres.${EXPECTED_PROJECT_REF}`
      && connection.password === "p@ssword"
      && connection.database === "postgres"
      && connection.port === "5432"
      && connection.sslmode === "require",
    "database_url_valid_fixture_rejected",
  );
  for (const invalidUri of [
    postgresFixtureUri({ projectRef: "wrongproject" }),
    postgresFixtureUri({ database: "other" }),
    `${validUri}#fragment`,
    `${validUri}&application_name=unsafe`,
    postgresFixtureUri({ port: "70000" }),
    postgresFixtureUri({ password: "bad%ZZ" }),
  ]) {
    expectSafeFailure(() => parsePostgresConnectionUri(invalidUri), "database_url_rejected");
  }
  const sourceEnvironment = {
    Path: "fixture-path",
    SITAA_B3A_DB_URL: validUri,
    sitaa_b3a_service_role_key: "fixture-sensitive-value",
    PGHOST: "untrusted-host",
    pgpassword: "untrusted-password",
    SAFE_FIXTURE: "preserved",
  };
  const sourceEnvironmentBefore = JSON.stringify(sourceEnvironment);
  const childEnvironment = postgresChildEnvironment(connection, sourceEnvironment);
  requireCondition(
    JSON.stringify(sourceEnvironment) === sourceEnvironmentBefore
      && childEnvironment.SAFE_FIXTURE === "preserved"
      && childEnvironment.PGHOST === connection.hostname
      && childEnvironment.PGPASSWORD === connection.password
      && !Object.keys(childEnvironment).some((key) => key.toUpperCase().startsWith("SITAA_B3A_"))
      && !("pgpassword" in childEnvironment),
    "postgres_child_environment_fixture_rejected",
  );
  const processEnvironmentBefore = JSON.stringify(Object.entries(process.env).sort(([left], [right]) => left.localeCompare(right)));
  postgresChildEnvironment(connection);
  const processEnvironmentAfter = JSON.stringify(Object.entries(process.env).sort(([left], [right]) => left.localeCompare(right)));
  requireCondition(processEnvironmentBefore === processEnvironmentAfter, "process_environment_mutated_fixture_rejected");
  const opaquePublicFixture = "sb_publishable_fixture_public";
  const opaqueSecretFixture = "sb_secret_fixture_service";
  const legacyAnonFixture = "legacyAnonHeader.legacyAnonPayload.legacyAnonSignature";
  const legacyServiceFixture = "legacyServiceHeader.legacyServicePayload.legacyServiceSignature";
  const userJwtFixture = "userHeader.userPayload.userSignature";
  requireCondition(
    validatePublicApiKey(opaquePublicFixture) === opaquePublicFixture
      && validatePublicApiKey(legacyAnonFixture) === legacyAnonFixture
      && validatePrivilegedApiKey(opaqueSecretFixture) === opaqueSecretFixture
      && validatePrivilegedApiKey(legacyServiceFixture) === legacyServiceFixture,
    "api_key_shape_fixture_rejected",
  );
  expectSafeFailure(() => validatePublicApiKey(opaqueSecretFixture), "publishable_key_shape_rejected");
  expectSafeFailure(() => validatePrivilegedApiKey(opaquePublicFixture), "privileged_key_shape_rejected");
  const captureTransportFacts = async (apiKey, authorization) => {
    const originalHeaders = new Headers({
      apikey: apiKey,
      aUtHoRiZaTiOn: authorization,
      "x-fixture": "preserved",
    });
    const originalInit = { method: "GET", headers: originalHeaders };
    const facts = {
      apikeyPreserved: false,
      authorizationAbsent: false,
      authorizationPreserved: false,
      headersCloned: false,
      initCloned: false,
      inputUnchanged: false,
      signalPresent: false,
      originalsUnchanged: false,
    };
    const fakeFetch = async (input, receivedInit) => {
      facts.apikeyPreserved = receivedInit.headers.get("apikey") === apiKey;
      facts.authorizationAbsent = !receivedInit.headers.has("authorization");
      facts.authorizationPreserved = receivedInit.headers.get("authorization") === authorization;
      facts.headersCloned = receivedInit.headers !== originalHeaders;
      facts.initCloned = receivedInit !== originalInit;
      facts.inputUnchanged = input === "https://fixture.invalid/transport";
      facts.signalPresent = receivedInit.signal instanceof AbortSignal;
      return Object.freeze({ ok: true });
    };
    await createApiKeyAwareBoundedFetch(apiKey, fakeFetch)(
      "https://fixture.invalid/transport",
      originalInit,
    );
    facts.originalsUnchanged = originalHeaders.get("authorization") === authorization
      && originalHeaders.get("apikey") === apiKey
      && !("signal" in originalInit);
    return Object.freeze(facts);
  };
  const opaquePublicFacts = await captureTransportFacts(
    opaquePublicFixture,
    `Bearer ${opaquePublicFixture}`,
  );
  const opaqueSecretFacts = await captureTransportFacts(
    opaqueSecretFixture,
    `Bearer ${opaqueSecretFixture}`,
  );
  const legacyAnonFacts = await captureTransportFacts(
    legacyAnonFixture,
    `Bearer ${legacyAnonFixture}`,
  );
  const legacyServiceFacts = await captureTransportFacts(
    legacyServiceFixture,
    `Bearer ${legacyServiceFixture}`,
  );
  const userJwtFacts = await captureTransportFacts(
    opaquePublicFixture,
    `Bearer ${userJwtFixture}`,
  );
  requireCondition(
    opaquePublicFacts.apikeyPreserved && opaquePublicFacts.authorizationAbsent
      && opaqueSecretFacts.apikeyPreserved && opaqueSecretFacts.authorizationAbsent
      && legacyAnonFacts.apikeyPreserved && legacyAnonFacts.authorizationPreserved
      && legacyServiceFacts.apikeyPreserved && legacyServiceFacts.authorizationPreserved
      && userJwtFacts.apikeyPreserved && userJwtFacts.authorizationPreserved
      && [opaquePublicFacts, opaqueSecretFacts, legacyAnonFacts, legacyServiceFacts, userJwtFacts]
        .every((facts) => facts.headersCloned && facts.initCloned && facts.inputUnchanged
          && facts.signalPresent && facts.originalsUnchanged),
    "api_key_transport_fixture_rejected",
  );
  const hangingFetch = (_input, init) => new Promise((_resolve, reject) => {
    const keepAlive = setTimeout(() => {}, 1_000);
    init.signal.addEventListener("abort", () => {
      clearTimeout(keepAlive);
      reject(init.signal.reason);
    }, { once: true });
  });
  await expectSafeFailureAsync(async () => {
    try {
      await createApiKeyAwareBoundedFetch(opaquePublicFixture, hangingFetch, 10)(
        "https://fixture.invalid/timeout",
      );
    } catch (error) {
      fail(authRequestFailureCode(error, "publishable_key_bootstrap_preflight_rejected"));
    }
  }, "auth_request_timeout");
  const priorController = new AbortController();
  const combinedInit = apiKeyAwareRequestInit(
    opaquePublicFixture,
    { headers: { apikey: opaquePublicFixture }, signal: priorController.signal },
    1_000,
  );
  requireCondition(
    combinedInit.signal !== priorController.signal && !combinedInit.signal.aborted,
    "prior_abort_signal_combination_fixture_rejected",
  );
  priorController.abort(new DOMException("fixture", "AbortError"));
  await Promise.resolve();
  requireCondition(combinedInit.signal.aborted, "prior_abort_signal_propagation_fixture_rejected");
  const publicClientFixture = (result) => ({
    from: (relation) => {
      requireCondition(relation === "system_health", "publishable_relation_fixture_rejected");
      return {
        select: (columns) => {
          requireCondition(columns === "status", "publishable_columns_fixture_rejected");
          return { limit: async (limit) => {
            requireCondition(limit === 1, "publishable_limit_fixture_rejected");
            if (result instanceof Error) throw result;
            return result;
          } };
        },
      };
    },
  });
  await publishableKeyBootstrapPreflight(publicClientFixture({ data: [], error: null }));
  await publishableKeyBootstrapPreflight(publicClientFixture({ data: [{ status: "ok" }], error: null }));
  await expectSafeFailureAsync(
    () => publishableKeyBootstrapPreflight(publicClientFixture({ data: [{ status: "degraded" }], error: null })),
    "system_health_not_ok",
  );
  await expectSafeFailureAsync(
    () => publishableKeyBootstrapPreflight(publicClientFixture({ data: [{ status: "ok", extra: true }], error: null })),
    "system_health_response_malformed",
  );
  await expectSafeFailureAsync(
    () => publishableKeyBootstrapPreflight(publicClientFixture({ data: [{ status: "ok" }, { status: "ok" }], error: null })),
    "system_health_response_malformed",
  );
  await expectSafeFailureAsync(
    () => publishableKeyBootstrapPreflight(publicClientFixture({ data: null, error: { code: "fixture" } })),
    "publishable_key_bootstrap_preflight_rejected",
  );
  await expectSafeFailureAsync(
    () => publishableKeyBootstrapPreflight(publicClientFixture({ data: null, error: { status: 401 } })),
    "publishable_key_bootstrap_preflight_rejected",
  );
  await expectSafeFailureAsync(
    () => publishableKeyBootstrapPreflight(publicClientFixture(
      Object.assign(new Error("fixture"), { name: "TimeoutError" }),
    )),
    "auth_request_timeout",
  );

  const repairFixture = {
    version: VERSION,
    target_email: email,
    target_uuid: null,
    original_oid: metadata.oid,
    original_acl_base64: Buffer.from(EXPECTED_HANDLER_ACL, "utf8").toString("base64"),
    original_md5: metadata.md5,
    snapshot_sha256: hashBuffer(Buffer.from(validateSnapshotText(snapshotDefinition), "utf8")),
    snapshot_relative_path: "supabase/reconciliation/b3a_matrix_failure_recovery_target_handler_snapshot.local.sql",
    phase: "handler_captured",
  };
  const predecessorRepairFixture = {
    ...repairFixture,
    version: RECOVERABLE_PREDECESSOR_VERSION,
  };
  const fixtureRoot = fs.mkdtempSync(path.join(process.env.TEMP ?? repoRoot, "sitaa-b3a-target-bundle-fixture-"));
  try {
    expectSafeFailure(
      () => validateRepair({
        ...repairFixture,
        original_acl_base64: Buffer.from("service_role_secret_material_must_be_rejected", "utf8").toString("base64"),
      }),
      "repair_acl_rejected",
    );
    const writeBundlePair = (repairFile, snapshotFile, repairValue = repairFixture, options = {}) => {
      fs.writeFileSync(repairFile, `${JSON.stringify(repairValue, null, 2)}\n`, "utf8");
      fs.writeFileSync(snapshotFile, validateSnapshotText(snapshotDefinition), "utf8");
      validateBundleFiles(repairFile, snapshotFile, options);
    };
    const predecessorRoot = path.join(fixtureRoot, "recoverable-predecessor");
    fs.mkdirSync(predecessorRoot);
    const predecessorRepairPath = path.join(predecessorRoot, "handler_repair.local.json");
    const predecessorSnapshotPath = path.join(predecessorRoot, "handler_snapshot.local.sql");
    writeBundlePair(
      predecessorRepairPath,
      predecessorSnapshotPath,
      predecessorRepairFixture,
      RECOVERABLE_REPAIR_OPTIONS,
    );
    const predecessorRepairBefore = fs.readFileSync(predecessorRepairPath);
    const predecessorSnapshotBefore = fs.readFileSync(predecessorSnapshotPath);
    const predecessorRepairHashBefore = hashBuffer(predecessorRepairBefore);
    const predecessorSnapshotHashBefore = hashBuffer(predecessorSnapshotBefore);
    expectSafeFailure(
      () => validateBundleFiles(predecessorRepairPath, predecessorSnapshotPath),
      "repair_identity_rejected",
    );
    const predecessorBundle = validateBundleFiles(
      predecessorRepairPath,
      predecessorSnapshotPath,
      RECOVERABLE_REPAIR_OPTIONS,
    );
    const predecessorRestoreSql = handlerRestoreSql(predecessorBundle.snapshot, metadata);
    requireCondition(
      predecessorBundle.repair.version === RECOVERABLE_PREDECESSOR_VERSION
        && predecessorRestoreSql.includes("$function$;\ndo $verify$")
        && fs.readFileSync(predecessorRepairPath).equals(predecessorRepairBefore)
        && fs.readFileSync(predecessorSnapshotPath).equals(predecessorSnapshotBefore)
        && hashBuffer(fs.readFileSync(predecessorRepairPath)) === predecessorRepairHashBefore
        && hashBuffer(fs.readFileSync(predecessorSnapshotPath)) === predecessorSnapshotHashBefore,
      "predecessor_bundle_read_only_acceptance_fixture_rejected",
    );
    expectSafeFailure(
      () => validateRepair(
        { ...predecessorRepairFixture, version: "2026-08-04-b3a-failure-target-bootstrap-v5" },
        RECOVERABLE_REPAIR_OPTIONS,
      ),
      "repair_identity_rejected",
    );

    const predecessorEvidenceRoot = path.join(fixtureRoot, "predecessor-evidence-rejected");
    fs.mkdirSync(predecessorEvidenceRoot);
    const predecessorEvidencePath = path.join(predecessorEvidenceRoot, "bootstrap.local.txt");
    const predecessorPostcheckPath = path.join(predecessorEvidenceRoot, "postcheck.local.txt");
    const currentEvidence = approvedEvidencePairContents();
    fs.writeFileSync(
      predecessorEvidencePath,
      currentEvidence.bootstrap.replace(CURRENT_BOOTSTRAP_VERSION, RECOVERABLE_PREDECESSOR_VERSION),
      "utf8",
    );
    fs.writeFileSync(
      predecessorPostcheckPath,
      currentEvidence.postcheck.replace(CURRENT_BOOTSTRAP_VERSION, RECOVERABLE_PREDECESSOR_VERSION),
      "utf8",
    );
    expectSafeFailure(
      () => inspectApprovedEvidencePair(predecessorEvidencePath, predecessorPostcheckPath),
      "bootstrap_evidence_invalid",
    );

    expectSafeFailure(
      () => cleanupApprovedProvisioningArtifacts({
        repairPath: predecessorRepairPath,
        snapshotPath: predecessorSnapshotPath,
        evidencePath: path.join(predecessorRoot, "bootstrap.local.txt"),
        postcheckPath: path.join(predecessorRoot, "postcheck.local.txt"),
        evidenceState: "absent",
        remotePostcheckApproved: false,
      }),
      "post_success_cleanup_not_authorized",
    );
    requireCondition(
      fs.readFileSync(predecessorRepairPath).equals(predecessorRepairBefore)
        && fs.readFileSync(predecessorSnapshotPath).equals(predecessorSnapshotBefore),
      "failed_predecessor_profile_preservation_fixture_rejected",
    );

    const predecessorSuccessRoot = path.join(fixtureRoot, "predecessor-success-cleanup");
    fs.mkdirSync(predecessorSuccessRoot);
    const predecessorSuccessRepair = path.join(predecessorSuccessRoot, "handler_repair.local.json");
    const predecessorSuccessSnapshot = path.join(predecessorSuccessRoot, "handler_snapshot.local.sql");
    const predecessorSuccessEvidence = path.join(predecessorSuccessRoot, "bootstrap.local.txt");
    const predecessorSuccessPostcheck = path.join(predecessorSuccessRoot, "postcheck.local.txt");
    writeBundlePair(
      predecessorSuccessRepair,
      predecessorSuccessSnapshot,
      predecessorRepairFixture,
      RECOVERABLE_REPAIR_OPTIONS,
    );
    publishApprovedEvidencePair(predecessorSuccessEvidence, predecessorSuccessPostcheck);
    cleanupApprovedProvisioningArtifacts({
      repairPath: predecessorSuccessRepair,
      snapshotPath: predecessorSuccessSnapshot,
      evidencePath: predecessorSuccessEvidence,
      postcheckPath: predecessorSuccessPostcheck,
      evidenceState: "complete",
      remotePostcheckApproved: true,
    });
    requireCondition(
      Object.values(bundleJournalPaths(predecessorSuccessRepair, predecessorSuccessSnapshot))
        .every((filePath) => !fs.existsSync(filePath))
        && inspectApprovedEvidencePair(predecessorSuccessEvidence, predecessorSuccessPostcheck).state === "complete",
      "predecessor_success_cleanup_fixture_rejected",
    );
    const emptyRoot = path.join(fixtureRoot, "bundle-empty");
    fs.mkdirSync(emptyRoot);
    const emptyRepairPath = path.join(emptyRoot, "handler_repair.local.json");
    const emptySnapshotPath = path.join(emptyRoot, "handler_snapshot.local.sql");
    requireCondition(
      recoverRepairBundle(emptyRepairPath, emptySnapshotPath) === "absent",
      "bundle_absent_fixture_rejected",
    );

    for (const generation of ["current", "next", "previous"]) {
      const stageRoot = path.join(fixtureRoot, `bundle-valid-${generation}`);
      fs.mkdirSync(stageRoot);
      const repairPath = path.join(stageRoot, "handler_repair.local.json");
      const snapshotPath = path.join(stageRoot, "handler_snapshot.local.sql");
      const journal = bundleJournalPaths(repairPath, snapshotPath);
      const repairFile = generation === "current"
        ? journal.repairPath
        : generation === "next" ? journal.repairNext : journal.repairPrevious;
      const snapshotFile = generation === "current"
        ? journal.snapshotPath
        : generation === "next" ? journal.snapshotNext : journal.snapshotPrevious;
      writeBundlePair(repairFile, snapshotFile);
      const recovered = recoverRepairBundle(repairPath, snapshotPath);
      requireCondition(
        recovered === (generation === "current" ? "current" : `recovered_${generation}`)
          && tryValidateBundleFiles(repairPath, snapshotPath) !== null,
        `bundle_valid_${generation}_fixture_rejected`,
      );
    }

    const assertCorruptBundlePreserved = (fixtureName, artifactWriter) => {
      const stageRoot = path.join(fixtureRoot, fixtureName);
      fs.mkdirSync(stageRoot);
      const repairPath = path.join(stageRoot, "handler_repair.local.json");
      const snapshotPath = path.join(stageRoot, "handler_snapshot.local.sql");
      const journal = bundleJournalPaths(repairPath, snapshotPath);
      artifactWriter(journal);
      const before = new Map(
        Object.values(journal).filter((filePath) => fs.existsSync(filePath))
          .map((filePath) => [filePath, fs.readFileSync(filePath)]),
      );
      expectSafeFailure(
        () => recoverRepairBundle(repairPath, snapshotPath),
        "handler_repair_bundle_corrupt",
      );
      requireCondition(
        before.size > 0
          && [...before.entries()].every(([filePath, contents]) => (
            fs.existsSync(filePath) && fs.readFileSync(filePath).equals(contents)
          )),
        `${fixtureName}_preservation_fixture_rejected`,
      );
      return { repairPath, snapshotPath, before };
    };
    const corruptCurrent = assertCorruptBundlePreserved("bundle-corrupt-current", (journal) => {
      fs.writeFileSync(journal.repairPath, "{}\n", "utf8");
      fs.writeFileSync(journal.snapshotPath, "invalid\n", "utf8");
    });
    assertCorruptBundlePreserved("bundle-orphan-repair", (journal) => {
      fs.writeFileSync(journal.repairPath, "{}\n", "utf8");
    });
    assertCorruptBundlePreserved("bundle-orphan-snapshot", (journal) => {
      fs.writeFileSync(journal.snapshotPath, "invalid\n", "utf8");
    });
    assertCorruptBundlePreserved("bundle-all-invalid", (journal) => {
      for (const filePath of Object.values(journal)) fs.writeFileSync(filePath, "invalid\n", "utf8");
    });
    authHandlerGateActive = true;
    try {
      expectSafeFailure(
        () => readRepair(corruptCurrent.repairPath, corruptCurrent.snapshotPath),
        "handler_repair_bundle_corrupt",
      );
      requireCondition(
        [...corruptCurrent.before.keys()].every((filePath) => fs.existsSync(filePath)),
        "temporary_handler_corrupt_bundle_preservation_fixture_rejected",
      );
    } finally {
      authHandlerGateActive = false;
    }
    for (const publishStage of ["after_next", "after_snapshot", "after_repair"]) {
      const stageRoot = path.join(fixtureRoot, `publish-${publishStage}`);
      fs.mkdirSync(stageRoot);
      const repairPath = path.join(stageRoot, "handler_repair.local.json");
      const snapshotPath = path.join(stageRoot, "handler_snapshot.local.sql");
      const repaired = publishRepairBundle(repairPath, snapshotPath, repairFixture, snapshotDefinition, publishStage);
      requireCondition(repairAcl(repaired) === EXPECTED_HANDLER_ACL, "repair_acl_roundtrip_fixture_rejected");
      const journal = bundleJournalPaths(repairPath, snapshotPath);
      requireCondition(
        fs.existsSync(repairPath) && fs.existsSync(snapshotPath)
          && Object.entries(journal).filter(([key]) => !["repairPath", "snapshotPath"].includes(key))
            .every(([, filePath]) => !fs.existsSync(filePath)),
        "bundle_publication_fixture_rejected",
      );
    }
    for (const updateStage of ["after_next", "after_previous", "after_current"]) {
      const stageRoot = path.join(fixtureRoot, `update-${updateStage}`);
      fs.mkdirSync(stageRoot);
      const repairPath = path.join(stageRoot, "handler_repair.local.json");
      const snapshotPath = path.join(stageRoot, "handler_snapshot.local.sql");
      publishRepairBundle(repairPath, snapshotPath, repairFixture, snapshotDefinition);
      updateRepair(repairPath, snapshotPath, { phase: "handler_gate_open" }, updateStage);
      const recovered = readRepair(repairPath, snapshotPath);
      requireCondition(repairAcl(recovered) === EXPECTED_HANDLER_ACL, "bundle_update_fixture_rejected");
      const journal = bundleJournalPaths(repairPath, snapshotPath);
      requireCondition(
        fs.existsSync(repairPath) && fs.existsSync(snapshotPath)
          && Object.entries(journal).filter(([key]) => !["repairPath", "snapshotPath"].includes(key))
            .every(([, filePath]) => !fs.existsSync(filePath)),
        "bundle_update_cleanup_fixture_rejected",
      );
    }

    const correctRoot = path.join(fixtureRoot, "snapshot-correct");
    fs.mkdirSync(correctRoot);
    const correctRepairPath = path.join(correctRoot, "handler_repair.local.json");
    const correctSnapshotPath = path.join(correctRoot, "handler_snapshot.local.sql");
    publishRepairBundle(correctRepairPath, correctSnapshotPath, repairFixture, snapshotDefinition);
    requireCondition(
      validateBundleFiles(correctRepairPath, correctSnapshotPath).repair.snapshot_sha256 === repairFixture.snapshot_sha256,
      "snapshot_sha256_correct_fixture_rejected",
    );

    for (const [fixtureName, damagedSnapshot] of [
      ["snapshot-truncated", "CREATE OR REPLACE FUNCTION public.handle_sitaa_auth_user_created()"],
      ["snapshot-modified", snapshotDefinition.replace("return new", "return null")],
    ]) {
      const stageRoot = path.join(fixtureRoot, fixtureName);
      fs.mkdirSync(stageRoot);
      const repairPath = path.join(stageRoot, "handler_repair.local.json");
      const snapshotPath = path.join(stageRoot, "handler_snapshot.local.sql");
      publishRepairBundle(repairPath, snapshotPath, repairFixture, snapshotDefinition);
      fs.writeFileSync(snapshotPath, validateSnapshotText(damagedSnapshot), "utf8");
      requireCondition(tryValidateBundleFiles(repairPath, snapshotPath) === null, `${fixtureName}_fixture_rejected`);
    }

    const modifiedHashRoot = path.join(fixtureRoot, "repair-hash-modified");
    fs.mkdirSync(modifiedHashRoot);
    const modifiedHashRepairPath = path.join(modifiedHashRoot, "handler_repair.local.json");
    const modifiedHashSnapshotPath = path.join(modifiedHashRoot, "handler_snapshot.local.sql");
    publishRepairBundle(modifiedHashRepairPath, modifiedHashSnapshotPath, repairFixture, snapshotDefinition);
    const modifiedHashRepair = JSON.parse(fs.readFileSync(modifiedHashRepairPath, "utf8"));
    modifiedHashRepair.snapshot_sha256 = "0".repeat(64);
    fs.writeFileSync(modifiedHashRepairPath, `${JSON.stringify(modifiedHashRepair, null, 2)}\n`, "utf8");
    requireCondition(
      tryValidateBundleFiles(modifiedHashRepairPath, modifiedHashSnapshotPath) === null,
      "repair_snapshot_hash_modified_fixture_rejected",
    );

    const previousRoot = path.join(fixtureRoot, "invalid-next-valid-previous");
    fs.mkdirSync(previousRoot);
    const previousRepairPath = path.join(previousRoot, "handler_repair.local.json");
    const previousSnapshotPath = path.join(previousRoot, "handler_snapshot.local.sql");
    publishRepairBundle(previousRepairPath, previousSnapshotPath, repairFixture, snapshotDefinition);
    const previousJournal = bundleJournalPaths(previousRepairPath, previousSnapshotPath);
    fs.renameSync(previousRepairPath, previousJournal.repairPrevious);
    fs.renameSync(previousSnapshotPath, previousJournal.snapshotPrevious);
    fs.writeFileSync(previousJournal.repairNext, "{}\n", "utf8");
    fs.writeFileSync(previousJournal.snapshotNext, "invalid\n", "utf8");
    requireCondition(
      recoverRepairBundle(previousRepairPath, previousSnapshotPath) === "recovered_previous"
        && tryValidateBundleFiles(previousRepairPath, previousSnapshotPath) !== null,
      "invalid_next_valid_previous_fixture_rejected",
    );

    const partialNextRoot = path.join(fixtureRoot, "valid-current-partial-next");
    fs.mkdirSync(partialNextRoot);
    const partialNextRepairPath = path.join(partialNextRoot, "handler_repair.local.json");
    const partialNextSnapshotPath = path.join(partialNextRoot, "handler_snapshot.local.sql");
    publishRepairBundle(partialNextRepairPath, partialNextSnapshotPath, repairFixture, snapshotDefinition);
    const partialNextJournal = bundleJournalPaths(partialNextRepairPath, partialNextSnapshotPath);
    fs.writeFileSync(partialNextJournal.repairNext, "{\n", "utf8");
    requireCondition(
      recoverRepairBundle(partialNextRepairPath, partialNextSnapshotPath) === "current"
        && !fs.existsSync(partialNextJournal.repairNext)
        && tryValidateBundleFiles(partialNextRepairPath, partialNextSnapshotPath) !== null,
      "valid_current_partial_next_fixture_rejected",
    );

    const evidenceScenarios = ["absent", "complete", "bootstrap-only", "postcheck-only"];
    for (const scenario of evidenceScenarios) {
      const stageRoot = path.join(fixtureRoot, `evidence-${scenario}`);
      fs.mkdirSync(stageRoot);
      const bootstrapPath = path.join(stageRoot, "bootstrap.local.txt");
      const postcheckPath = path.join(stageRoot, "postcheck.local.txt");
      const expected = approvedEvidencePairContents();
      if (scenario === "complete") publishApprovedEvidencePair(bootstrapPath, postcheckPath);
      if (scenario === "bootstrap-only") fs.writeFileSync(bootstrapPath, expected.bootstrap, "utf8");
      if (scenario === "postcheck-only") fs.writeFileSync(postcheckPath, expected.postcheck, "utf8");
      const expectedState = scenario === "absent" ? "absent" : scenario === "complete" ? "complete" : "partial";
      requireCondition(inspectApprovedEvidencePair(bootstrapPath, postcheckPath).state === expectedState, `evidence_${scenario}_fixture_rejected`);
      if (scenario !== "absent") {
        publishApprovedEvidencePair(bootstrapPath, postcheckPath);
        requireCondition(inspectApprovedEvidencePair(bootstrapPath, postcheckPath).state === "complete", `evidence_${scenario}_recovery_fixture_rejected`);
      }
    }

    for (const interruptAt of ["after_bootstrap_next", "after_bootstrap", "after_postcheck_next", "after_postcheck"]) {
      const stageRoot = path.join(fixtureRoot, `evidence-interrupt-${interruptAt}`);
      fs.mkdirSync(stageRoot);
      const bootstrapPath = path.join(stageRoot, "bootstrap.local.txt");
      const postcheckPath = path.join(stageRoot, "postcheck.local.txt");
      try {
        publishApprovedEvidencePair(bootstrapPath, postcheckPath, interruptAt);
      } catch {
        // La segunda ejecución debe cerrar cualquier journal parcial recuperable.
      }
      publishApprovedEvidencePair(bootstrapPath, postcheckPath);
      const inspection = inspectApprovedEvidencePair(bootstrapPath, postcheckPath);
      requireCondition(
        inspection.state === "complete"
          && !fs.existsSync(inspection.journal.bootstrapNext)
          && !fs.existsSync(inspection.journal.postcheckNext),
        "evidence_interruption_recovery_fixture_rejected",
      );
    }

    const cleanupFixturePaths = (stageRoot) => {
      const repairPath = path.join(stageRoot, "handler_repair.local.json");
      const snapshotPath = path.join(stageRoot, "handler_snapshot.local.sql");
      const evidencePath = path.join(stageRoot, "bootstrap.local.txt");
      const postcheckPath = path.join(stageRoot, "postcheck.local.txt");
      return {
        repairPath,
        snapshotPath,
        evidencePath,
        postcheckPath,
        bundlePaths: Object.values(bundleJournalPaths(repairPath, snapshotPath)),
      };
    };
    for (let mask = 0; mask < 64; mask += 1) {
      const stageRoot = path.join(fixtureRoot, `post-success-subset-${mask}`);
      fs.mkdirSync(stageRoot);
      const cleanup = cleanupFixturePaths(stageRoot);
      publishApprovedEvidencePair(cleanup.evidencePath, cleanup.postcheckPath);
      cleanup.bundlePaths.forEach((filePath, index) => {
        if ((mask & (1 << index)) !== 0) fs.writeFileSync(filePath, `orphan-${index}\n`, "utf8");
      });
      cleanupApprovedProvisioningArtifacts({
        ...cleanup,
        evidenceState: "complete",
        remotePostcheckApproved: true,
      });
      requireCondition(
        postSuccessCleanupPaths(
          cleanup.repairPath,
          cleanup.snapshotPath,
          cleanup.evidencePath,
          cleanup.postcheckPath,
        ).every((filePath) => !fs.existsSync(filePath)),
        `post_success_subset_${mask}_fixture_rejected`,
      );
    }

    const partialRoot = path.join(fixtureRoot, "post-success-partial-evidence");
    fs.mkdirSync(partialRoot);
    const partialCleanup = cleanupFixturePaths(partialRoot);
    const approvedEvidence = approvedEvidencePairContents();
    fs.writeFileSync(partialCleanup.evidencePath, approvedEvidence.bootstrap, "utf8");
    partialCleanup.bundlePaths.forEach((filePath, index) => {
      if (index % 2 === 0) fs.writeFileSync(filePath, `partial-orphan-${index}\n`, "utf8");
    });
    const partialState = inspectApprovedEvidencePair(
      partialCleanup.evidencePath,
      partialCleanup.postcheckPath,
    ).state;
    requireCondition(partialState === "partial", "partial_evidence_cleanup_setup_fixture_rejected");
    publishApprovedEvidencePair(partialCleanup.evidencePath, partialCleanup.postcheckPath);
    cleanupApprovedProvisioningArtifacts({
      ...partialCleanup,
      evidenceState: partialState,
      remotePostcheckApproved: true,
    });
    requireCondition(
      inspectApprovedEvidencePair(partialCleanup.evidencePath, partialCleanup.postcheckPath).state === "complete"
        && postSuccessCleanupPaths(
          partialCleanup.repairPath,
          partialCleanup.snapshotPath,
          partialCleanup.evidencePath,
          partialCleanup.postcheckPath,
        ).every((filePath) => !fs.existsSync(filePath)),
      "partial_evidence_postcheck_cleanup_fixture_rejected",
    );

    const retryRoot = path.join(fixtureRoot, "post-success-unlink-retry");
    fs.mkdirSync(retryRoot);
    const retryCleanup = cleanupFixturePaths(retryRoot);
    publishApprovedEvidencePair(retryCleanup.evidencePath, retryCleanup.postcheckPath);
    retryCleanup.bundlePaths.forEach((filePath, index) => {
      fs.writeFileSync(filePath, `retry-orphan-${index}\n`, "utf8");
    });
    let successfulDeletes = 0;
    let simulatedFailure = false;
    expectSafeFailure(
      () => cleanupApprovedProvisioningArtifacts({
        ...retryCleanup,
        evidenceState: "complete",
        remotePostcheckApproved: true,
        unlinkFile: (filePath) => {
          if (successfulDeletes === 1 && !simulatedFailure) {
            simulatedFailure = true;
            throw new Error("fixture_unlink_failure");
          }
          fs.unlinkSync(filePath);
          successfulDeletes += 1;
        },
      }),
      "repair_cleanup_required",
    );
    requireCondition(
      simulatedFailure
        && successfulDeletes === retryCleanup.bundlePaths.length - 1
        && retryCleanup.bundlePaths.filter((filePath) => fs.existsSync(filePath)).length === 1
        && inspectApprovedEvidencePair(retryCleanup.evidencePath, retryCleanup.postcheckPath).state === "complete",
      "partial_unlink_preserves_approved_evidence_fixture_rejected",
    );
    cleanupApprovedProvisioningArtifacts({
      ...retryCleanup,
      evidenceState: "complete",
      remotePostcheckApproved: true,
    });
    requireCondition(
      retryCleanup.bundlePaths.every((filePath) => !fs.existsSync(filePath)),
      "second_finalization_cleanup_fixture_rejected",
    );

    for (let index = 0; index < 6; index += 1) {
      const stageRoot = path.join(fixtureRoot, `pre-success-orphan-${index}`);
      fs.mkdirSync(stageRoot);
      const cleanup = cleanupFixturePaths(stageRoot);
      const orphanPath = cleanup.bundlePaths[index];
      const orphanContents = Buffer.from(`pre-success-orphan-${index}\n`, "utf8");
      fs.writeFileSync(orphanPath, orphanContents);
      expectSafeFailure(
        () => cleanupApprovedProvisioningArtifacts({
          ...cleanup,
          evidenceState: "absent",
          remotePostcheckApproved: false,
        }),
        "post_success_cleanup_not_authorized",
      );
      requireCondition(
        fs.existsSync(orphanPath) && fs.readFileSync(orphanPath).equals(orphanContents),
        `pre_success_orphan_${index}_preservation_fixture_rejected`,
      );
    }
  } finally {
    fs.rmSync(fixtureRoot, { recursive: true, force: true });
  }
  requireCondition(!fs.existsSync(fixtureRoot), "bundle_fixture_cleanup_rejected");

  const responseLoss = resolveCreateOutcome({
    attempt: { succeeded: false, errorCode: "auth_admin_unavailable" },
    matches: [{ id: target }],
  });
  requireCondition(responseLoss.classification === "response_lost_target_present", "create_response_loss_fixture_rejected");
  requireCondition(
    provisioningState({ userCount: 1, profileCount: 0 }) === "auth_only_profile_missing"
      && provisioningState({ userCount: 1, profileCount: 1 }) === "profile_already_created",
    "profile_resume_fixture_rejected",
  );
  let duplicateRejected = false;
  try {
    resolveCreateOutcome({
      attempt: { succeeded: true, errorCode: null },
      matches: [{ id: target }, { id: adminA }],
    });
  } catch (error) {
    duplicateRejected = error instanceof SafeFailure && error.code === "target_inventory_duplicated";
  }
  requireCondition(duplicateRejected, "duplicate_target_fixture_rejected");
  const profileSql = profileProvisionSql(target, email);
  assertControlledMutation(profileSql, "profile");
  const resumePrecheckSql = resumeProvisioningPrecheckSql(target, email, adminA, adminB);
  const missingProfilePrecheck = [
    "FAILURE_TARGET_RESUME_PRECHECK", "3", "3", "2", "2", "2", "1", "1", "0", "0", "0",
    EXPECTED_HANDLER_MD5, "2",
  ];
  const replayedProfilePrecheck = [
    "FAILURE_TARGET_RESUME_PRECHECK", "3", "3", "3", "2", "2", "1", "1", "1", "0", "0",
    EXPECTED_HANDLER_MD5, "2",
  ];
  const firstResumeState = assertResumeProvisioningPrecheck(missingProfilePrecheck);
  const secondResumeState = assertResumeProvisioningPrecheck(replayedProfilePrecheck);
  let simulatedProfileCount = 0;
  let simulatedProfileCreates = 0;
  const simulateIdempotentProfileResume = () => {
    const state = provisioningState({ userCount: 1, profileCount: simulatedProfileCount });
    if (state === "auth_only_profile_missing") {
      simulatedProfileCount += 1;
      simulatedProfileCreates += 1;
      return "created";
    }
    return "replayed";
  };
  requireCondition(
    profileSql.includes("outcome:='created'")
      && profileSql.includes("outcome:='replayed'")
      && (profileSql.match(/insert\s+into\s+public\.profiles/gi) ?? []).length === 1
      && normalizeEol(resumePrecheckSql).trim().startsWith("begin;\nset transaction read only;")
      && normalizeEol(resumePrecheckSql).trim().endsWith("rollback;")
      && firstResumeState === "auth_only_profile_missing"
      && secondResumeState === "profile_already_created"
      && simulateIdempotentProfileResume() === "created"
      && simulateIdempotentProfileResume() === "replayed"
      && simulatedProfileCreates === 1
      && simulatedProfileCount === 1,
    "profile_idempotency_fixture_rejected",
  );
  const canonicalTarget = {
    id: target,
    email,
    email_confirmed_at: "2026-08-03T12:00:00.000Z",
    banned_until: null,
    app_metadata: { sitaa_account_kind: "technical", sitaa_first_names: TARGET_FIRST_NAMES },
  };
  const centralUsers = [
    { id: adminA, email: "admin-a@example.invalid" },
    { id: adminB, email: "admin-b@example.invalid" },
  ];
  requireCondition(classifyResumeTargets(centralUsers, repairFixture).state === "zero", "resume_zero_target_fixture_rejected");
  const oneTarget = classifyResumeTargets([...centralUsers, canonicalTarget], repairFixture);
  requireCondition(oneTarget.state === "one" && oneTarget.user.id === target, "resume_one_target_fixture_rejected");
  expectSafeFailure(
    () => classifyResumeTargets([...centralUsers, canonicalTarget, { ...canonicalTarget, id: adminA }], repairFixture),
    "resume_target_inventory_duplicated",
  );
  requireCondition(
    classifyFinalizationTarget([...centralUsers, canonicalTarget]).id === target,
    "finalization_exact_target_fixture_rejected",
  );
  expectSafeFailure(
    () => classifyFinalizationTarget(centralUsers),
    "finalization_target_inventory_rejected",
  );
  expectSafeFailure(
    () => classifyFinalizationTarget([...centralUsers, canonicalTarget, { ...canonicalTarget, id: adminA }]),
    "finalization_target_inventory_duplicated",
  );

  let guardedInventoryRejected = false;
  let guardedInventoryCalls = 0;
  authHandlerGateActive = true;
  try {
    await listAllAuthUsers({ auth: { admin: { listUsers: async () => {
      guardedInventoryCalls += 1;
      return { data: { users: [] }, error: null };
    } } } });
  } catch (error) {
    guardedInventoryRejected = error instanceof SafeFailure
      && error.code === "auth_inventory_during_handler_gate_rejected";
  } finally {
    authHandlerGateActive = false;
  }
  requireCondition(guardedInventoryRejected && guardedInventoryCalls === 0, "handler_inventory_fence_fixture_rejected");

  const normalSource = normalizeEol(normalMain.toString());
  const baselinePosition = normalSource.lastIndexOf("assertBaseline");
  const secretPosition = normalSource.lastIndexOf("collectSecrets");
  const preflightPosition = normalSource.lastIndexOf("authAdminBootstrapPreflight");
  const publishablePreflightPosition = normalSource.lastIndexOf("publishableKeyBootstrapPreflight");
  const confirmationPosition = normalSource.lastIndexOf("OPEN_FAILURE_TARGET_BOOTSTRAP_WINDOW");
  const capturePosition = normalSource.lastIndexOf("handlerCaptureSql");
  requireCondition(
    baselinePosition >= 0 && secretPosition > baselinePosition && preflightPosition > secretPosition
      && publishablePreflightPosition > preflightPosition
      && confirmationPosition > publishablePreflightPosition && capturePosition > confirmationPosition,
    "auth_preflight_order_fixture_rejected",
  );
  const resumeBranchStart = normalSource.indexOf("if (resume)");
  const resumeBranchEnd = normalSource.indexOf(
    'requireCondition(evidenceState.state === "absent"',
    resumeBranchStart,
  );
  requireCondition(
    resumeBranchStart >= 0 && resumeBranchEnd > resumeBranchStart,
    "resume_branch_fixture_rejected",
  );
  const resumeBranch = normalSource.slice(resumeBranchStart, resumeBranchEnd);
  const resumeZeroStart = resumeBranch.indexOf('if (resumeState.state === "zero")');
  const resumeServicePreflight = resumeBranch.indexOf("authAdminBootstrapPreflight", resumeZeroStart);
  const resumePublishablePreflight = resumeBranch.indexOf("publishableKeyBootstrapPreflight", resumeZeroStart);
  const resumeConfirmation = resumeBranch.indexOf("RETRY_FAILURE_TARGET_CREATION", resumeZeroStart);
  const resumeHandlerGate = resumeBranch.indexOf("createWithinTemporaryHandlerGate", resumeZeroStart);
  requireCondition(
    resumeZeroStart >= 0
      && resumeServicePreflight > resumeZeroStart
      && resumePublishablePreflight > resumeServicePreflight
      && resumeConfirmation > resumePublishablePreflight
      && resumeHandlerGate > resumeConfirmation,
    "resume_zero_target_preflight_order_fixture_rejected",
  );
  const resumeExistingStart = resumeBranch.indexOf("} else {", resumeHandlerGate);
  const resumeExistingEnd = resumeBranch.indexOf(
    'requireCondition(user !== null, "resume_target_inventory_rejected")',
    resumeExistingStart,
  );
  requireCondition(
    resumeExistingStart >= 0 && resumeExistingEnd > resumeExistingStart,
    "resume_existing_target_branch_fixture_rejected",
  );
  const resumeExistingBranch = resumeBranch.slice(resumeExistingStart, resumeExistingEnd);
  requireCondition(
    resumeExistingBranch.includes("resumeProvisioningPrecheckSql")
      && resumeExistingBranch.includes("assertResumeProvisioningPrecheck")
      && resumeExistingBranch.includes("RESUME_FAILURE_TARGET_PROVISIONING")
      && !resumeExistingBranch.includes("attemptCreateAuthTarget")
      && !resumeExistingBranch.includes("createWithinTemporaryHandlerGate")
      && !resumeExistingBranch.includes("handlerGateSql")
      && !resumeExistingBranch.includes("createUser"),
    "resume_existing_target_no_auth_creation_fixture_rejected",
  );
  const createWindowSource = createWithinTemporaryHandlerGate.toString();
  requireCondition(
    createWindowSource.indexOf("attemptCreateAuthTarget") >= 0
      && createWindowSource.indexOf("restoreHandler") > createWindowSource.indexOf("attemptCreateAuthTarget")
      && createWindowSource.indexOf("resolveCreatedTargetAfterRestore") > createWindowSource.indexOf("restoreHandler"),
    "handler_restore_before_inventory_fixture_rejected",
  );
  const restoreSource = [
    handlerRestoreSql,
    restoreAttemptRejectionLines,
    restoreHandler,
  ].map((value) => value.toString()).join("\n");
  requireCondition(
    restoreSource.includes("assembleCapturedFunctionSql")
      && restoreSource.includes("AUTH_HANDLER_RESTORE_DIAGNOSTIC")
      && restoreSource.includes("classifyRestoreError")
      && !restoreHandler.toString().includes("stderr")
      && !restoreHandler.toString().includes("console.log(error")
      && !restoreHandler.toString().includes("console.error(error"),
    "restore_terminator_and_diagnostic_source_fixture_rejected",
  );
  const completionSource = normalizeEol(completeProvisioning.toString());
  const completionProfilePosition = completionSource.indexOf("profileProvisionSql");
  const completionLoginPosition = completionSource.indexOf("signInAndVerify");
  const completionPostcheckPosition = completionSource.indexOf("postcheckSql");
  const completionEvidencePosition = completionSource.indexOf("publishApprovedEvidencePair");
  const completionCleanupPosition = completionSource.indexOf("cleanupApprovedProvisioningArtifacts");
  requireCondition(
    completionProfilePosition >= 0
      && completionLoginPosition > completionProfilePosition
      && completionPostcheckPosition > completionLoginPosition
      && completionEvidencePosition > completionPostcheckPosition
      && completionCleanupPosition > completionEvidencePosition,
    "resume_failure_preserves_bundle_until_evidence_fixture_rejected",
  );
  const abandonSource = abandonProvisioningMain.toString();
  requireCondition(
    abandonSource.includes("ABANDON_FAILURE_TARGET_PROVISIONING")
      && abandonSource.includes("authAdminBootstrapPreflight")
      && abandonSource.includes("removeRepairArtifacts")
      && !abandonSource.includes("createUser")
      && !abandonSource.includes("deleteUser")
      && !abandonSource.includes("executeControlledMutation"),
    "abandon_mode_fixture_rejected",
  );
  requireCondition(
    normalSource.includes("if (resume)")
      && normalSource.includes("inspectApprovedEvidencePair")
      && normalSource.includes("finalizeProvisioningReadOnly")
      && normalSource.includes("RETRY_FAILURE_TARGET_CREATION")
      && normalSource.includes("completeProvisioning")
      && !normalSource.includes("deleteUser"),
    "resume_mode_fixture_rejected",
  );
  const finalizationSource = `${finalizeProvisioningMain.toString()}\n${finalizeProvisioningReadOnly.toString()}`;
  requireCondition(
    finalizationSource.includes("classifyFinalizationTarget")
      && finalizationSource.includes("postcheckSql")
      && finalizationSource.includes("publishApprovedEvidencePair")
      && finalizationSource.includes("cleanupApprovedProvisioningArtifacts")
      && finalizationSource.includes("FAILURE_TARGET_PROVISIONING_FINALIZATION|APPROVED")
      && finalizationSource.includes("AUTH_HANDLER_STATE|CANONICAL")
      && finalizationSource.includes("REPAIR_BUNDLE|ABSENT")
      && !finalizationSource.includes("readRepair")
      && !finalizationSource.includes("recoverRepairBundle")
      && !finalizationSource.includes("classifyResumeTargets")
      && !finalizationSource.includes("removeRepairArtifacts")
      && !finalizationSource.includes("attemptCreateAuthTarget")
      && !finalizationSource.includes("profileProvisionSql")
      && !finalizationSource.includes("signInAndVerify")
      && !finalizationSource.includes("executeControlledMutation")
      && !finalizationSource.includes("targetPassword"),
    "finalize_provisioning_only_fixture_rejected",
  );
  const resumeEvidencePosition = resumeBranch.indexOf('if (evidenceState.state !== "absent")');
  const resumeFinalizationPosition = resumeBranch.indexOf("finalizeProvisioningReadOnly", resumeEvidencePosition);
  const resumeRepairReadPosition = resumeBranch.indexOf("readRepair", resumeEvidencePosition);
  requireCondition(
    resumeEvidencePosition >= 0
      && resumeFinalizationPosition > resumeEvidencePosition
      && resumeRepairReadPosition > resumeFinalizationPosition,
    "resume_post_success_before_strict_repair_fixture_rejected",
  );
  const cleanupSource = cleanupApprovedProvisioningArtifacts.toString();
  requireCondition(
    cleanupSource.includes("post_success_cleanup_not_authorized")
      && cleanupSource.includes("remotePostcheckApproved === true")
      && cleanupSource.includes("repair_cleanup_required")
      && !cleanupSource.includes("readRepair")
      && !cleanupSource.includes("recoverRepairBundle"),
    "post_success_cleanup_authorization_fixture_rejected",
  );
  const clientFactorySource = createClient.toString();
  const keyInputSource = `${collectSecrets.toString()}\n${collectAbandonSecrets.toString()}`;
  const publicPreflightSource = publishableKeyBootstrapPreflight.toString();
  requireCondition(
    clientFactorySource.includes("createApiKeyAwareBoundedFetch(key)")
      && !clientFactorySource.includes("global: { fetch: boundedFetch")
      && keyInputSource.includes('readMasked("Project URL exacta: ")).trim()')
      && keyInputSource.includes('readMasked("Publishable/anon key: ")).trim()')
      && keyInputSource.includes('readMasked("Service role/secret key: ")).trim()')
      && !keyInputSource.includes('readMasked("Contraseña de Target C: ")).trim()')
      && publicPreflightSource.includes('.from("system_health")')
      && publicPreflightSource.includes('.select("status")')
      && publicPreflightSource.includes(".limit(1)")
      && !publicPreflightSource.includes(".eq("),
    "api_key_client_and_preflight_source_fixture_rejected",
  );
  const createCall = [".auth.admin", ".createUser("].join("");
  requireCondition(
    (attemptCreateAuthTarget.toString().match(new RegExp(createCall.replace(/[.*+?^${}()|[\]\\]/g, "\\$&"), "g")) ?? []).length === 1,
    "bootstrap_create_user_fixture_rejected",
  );
  console.log("B3A_FAILURE_TARGET_BOOTSTRAP_FIXTURES|APPROVED");
}

const repoRoot = path.resolve(process.env.SITAA_B3A_REPO_ROOT ?? "");
try {
  if (process.argv.includes("--self-test")) {
    requireCondition(repoRoot.length > 0, "repository_root_required");
    await runSelfTests(repoRoot);
  } else if (process.argv.includes("--read-only-probe")) {
    await readOnlyProbeMain();
  } else if (process.argv.includes("--resume-provisioning")) {
    await normalMain({ resume: true });
  } else if (process.argv.includes("--restore-handler-only")) {
    await restoreOnlyMain();
  } else if (process.argv.includes("--abandon-provisioning")) {
    await abandonProvisioningMain();
  } else if (process.argv.includes("--finalize-provisioning-only")) {
    await finalizeProvisioningMain();
  } else {
    await normalMain();
  }
} catch (error) {
  const code = error instanceof SafeFailure ? error.code : "unexpected_failure";
  const safeCode = /^[a-z][a-z0-9_]{0,79}$/.test(code) ? code : "unexpected_failure";
  if (safeCode === "auth_handler_repair_required") {
    console.error("AUTH_HANDLER_REPAIR_REQUIRED");
  } else if (SAFE_ERROR_CODES.has(safeCode)) {
    console.error(`FAILURE_TARGET_BOOTSTRAP|REJECTED|${safeCode}`);
  } else {
    console.error(`FAILURE_TARGET_BOOTSTRAP|REJECTED|${safeCode}`);
  }
  process.exitCode = 1;
} finally {
  createSupabaseClient = null;
}
'@

function Assert-TemporaryPath {
  param([Parameter(Mandatory = $true)][string]$Candidate)

  $rootWithSeparator = $repoRoot.TrimEnd(
    [System.IO.Path]::DirectorySeparatorChar,
    [System.IO.Path]::AltDirectorySeparatorChar
  ) + [System.IO.Path]::DirectorySeparatorChar
  if (-not $Candidate.StartsWith($rootWithSeparator, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "La ruta temporal quedó fuera de la raíz del repositorio."
  }
}

function Assert-ScriptEncoding {
  $bytes = [System.IO.File]::ReadAllBytes($PSCommandPath)
  if ($bytes.Length -lt 3 -or $bytes[0] -ne 0xEF -or $bytes[1] -ne 0xBB -or $bytes[2] -ne 0xBF) {
    throw "El arnés debe estar guardado como UTF-8 con BOM."
  }
  $text = Get-Content -Raw -LiteralPath $PSCommandPath
  foreach ($literal in @("Contraseña", "restauración", "técnico", "confirmación")) {
    if (-not $text.Contains($literal)) {
      throw "La validación UTF-8 de Windows PowerShell rechazó el arnés."
    }
  }
  if ($text.Contains([char]0x00C3) -or $text.Contains([char]0x00C2) -or $text.Contains([char]0x00E2) -or $text.Contains([char]0xFFFD)) {
    throw "Se detectó mojibake en el arnés."
  }
  if ([regex]::IsMatch($text, '(?<!\r)\n') -or [regex]::IsMatch($text, '\r(?!\n)')) {
    throw "El arnés debe conservar finales de línea CRLF."
  }
}

function Get-ArtifactFingerprint {
  param([Parameter(Mandatory = $true)][string]$Path)

  if (-not (Test-Path -LiteralPath $Path)) { return "ABSENT" }
  $item = Get-Item -LiteralPath $Path
  $hash = (Get-FileHash -Algorithm SHA256 -LiteralPath $Path).Hash
  return ($item.Length.ToString() + ":" + $hash)
}

try {
  if ($currentRoot -ne $repoRoot) {
    throw "Ejecuta el arnés desde la raíz del repositorio."
  }
  $modeCount = 0
  foreach ($mode in @($ValidateOnly, $ReadOnlyProbeOnly, $ResumeProvisioning, $RestoreHandlerOnly, $AbandonProvisioning, $FinalizeProvisioningOnly)) {
    if ($mode) { $modeCount++ }
  }
  if ($modeCount -gt 1) {
    throw "Los modos del arnés son mutuamente excluyentes."
  }
  Assert-ScriptEncoding
  Assert-TemporaryPath -Candidate $temporaryRoot
  $artifactRoot = Join-Path $repoRoot "supabase\reconciliation"
  $before = @{}
  foreach ($name in $protectedLocalArtifactNames) {
    $before[$name] = Get-ArtifactFingerprint -Path (Join-Path $artifactRoot $name)
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
  [System.IO.File]::WriteAllText($nodeModulePath, $nodeModule, [System.Text.UTF8Encoding]::new($false))
  $env:SITAA_B3A_REPO_ROOT = $repoRoot

  if ($ValidateOnly) {
    & node --check $nodeModulePath
    if ($LASTEXITCODE -ne 0) { throw "La validación sintáctica del módulo Node falló." }
    & node $nodeModulePath --self-test
    if ($LASTEXITCODE -ne 0) { throw "Las fixtures locales del bootstrap fallaron." }
    foreach ($name in $protectedLocalArtifactNames) {
      $after = Get-ArtifactFingerprint -Path (Join-Path $artifactRoot $name)
      if ($after -ne $before[$name]) { throw "ValidateOnly modificó un artefacto protegido." }
    }
    Write-Output "B3A_FAILURE_TARGET_BOOTSTRAP_STATIC_VALIDATION|APPROVED"
    return
  }

  if ([string]::IsNullOrWhiteSpace($env:SITAA_B3A_PROJECT_REF)) { throw "Falta SITAA_B3A_PROJECT_REF." }
  if ([string]::IsNullOrWhiteSpace($env:SITAA_B3A_DB_URL)) { throw "Falta SITAA_B3A_DB_URL." }

  if ($ReadOnlyProbeOnly) {
    & node $nodeModulePath --read-only-probe
  }
  elseif ($ResumeProvisioning) {
    & node $nodeModulePath --resume-provisioning
  }
  elseif ($RestoreHandlerOnly) {
    & node $nodeModulePath --restore-handler-only
  }
  elseif ($AbandonProvisioning) {
    & node $nodeModulePath --abandon-provisioning
  }
  elseif ($FinalizeProvisioningOnly) {
    & node $nodeModulePath --finalize-provisioning-only
  }
  else {
    & node $nodeModulePath
  }
  $nodeExitCode = $LASTEXITCODE
  if ($nodeExitCode -eq 2) { exit 2 }
  if ($nodeExitCode -ne 0) { throw "El bootstrap terminó sin aprobación." }
  if ($ReadOnlyProbeOnly) {
    foreach ($name in $protectedLocalArtifactNames) {
      $after = Get-ArtifactFingerprint -Path (Join-Path $artifactRoot $name)
      if ($after -ne $before[$name]) { throw "ReadOnlyProbeOnly modificó un artefacto protegido." }
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
