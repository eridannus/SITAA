param(
  [switch]$ValidateOnly
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$scriptRoot = Split-Path -Parent $PSCommandPath
$repoRoot = [System.IO.Path]::GetFullPath((Join-Path $scriptRoot ".."))
$currentRoot = [System.IO.Path]::GetFullPath((Get-Location).Path)
$temporaryRoot = [System.IO.Path]::GetFullPath(
  (Join-Path $repoRoot (".sitaa-b3a-runtime-" + [guid]::NewGuid().ToString("N")))
)
$nodeModulePath = Join-Path $temporaryRoot "hosted-auth-core.mjs"

$nodeModule = @'
import crypto from "node:crypto";
import fs from "node:fs";
import path from "node:path";
import process from "node:process";
import readline from "node:readline/promises";
import { spawnSync } from "node:child_process";
import { createClient } from "@supabase/supabase-js";

const EXPECTED_PROJECT_REF = "upttfqjogltvymnaubkg";
const EXPECTED_PROJECT_URL = `https://${EXPECTED_PROJECT_REF}.supabase.co`;
const HARNESS_VERSION = "2026-07-25-hosted-auth-core-v3";
const EXPECTED_SUPABASE_JS_VERSION = "2.110.1";
const OPERATOR_ABORT_EXIT_CODE = 2;
const EXPECTED_POSTCHECK =
  "B3A_0010_POSTCHECK|2|2|2|2|2|0|0|0|0|0|6|1|1|0|2|0|19|60";
const EXPECTED_EMAILS = new Map([
  ["admin_a", "b3a-admin-a-upttfqjo@example.invalid"],
  ["admin_b", "b3a-admin-b-upttfqjo@example.invalid"],
]);
const EXPECTED_FIRST_NAMES = new Map([
  ["admin_a", "Administrador Matriz A"],
  ["admin_b", "Administrador Matriz B"],
]);
const UUID_PATTERN =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const FORBIDDEN_EVIDENCE =
  /@|https?:|bearer|authorization|cookie|password|secret|service[_-]?role|access[_-]?token|refresh[_-]?token|eyj[a-z0-9_-]*\./i;
const SAFE_AUTH_CODES = new Set([
  "user_banned",
  "session_unavailable",
  "jwt_rejected",
  "invalid_credentials",
  "rate_limited",
  "request_timeout",
  "auth_rejected",
  "client_unavailable",
  "none",
]);
const FAILURE_PHASES = new Set([
  "before_confirmation",
  "before_deactivation",
  "deactivated",
  "suspended_observations",
  "before_reactivation",
  "reactivated",
  "final_postcheck",
]);
const AUTH_ACTIONS = [
  "account_auth_suspended",
  "account_auth_restored",
  "account_auth_suspension_failed",
  "account_auth_restoration_failed",
];
const B3A_FUNCTION_SIGNATURES = [
  "get_admin_account_auth_lifecycle_context_b3a(uuid)",
  "prepare_admin_account_auth_lifecycle_b3a(uuid,text,text,uuid)",
  "claim_admin_auth_operation_b3a(uuid,uuid)",
  "record_admin_auth_operation_result_b3a(uuid,uuid,integer,text,text)",
  "finalize_admin_account_auth_reactivation_b3a(uuid)",
  "guard_admin_auth_operation_b3a()",
];
const CLIENT_OPTIONS = {
  auth: {
    autoRefreshToken: false,
    persistSession: false,
    detectSessionInUrl: false,
  },
};
const runtimeState = {
  phase: "before_confirmation",
  irreversibleEvidencePersisted: false,
  dbUrl: null,
  adminAId: null,
  adminBId: null,
  evidencePath: null,
};

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

function classifyAuthError(error) {
  if (!error) return "none";
  const code = typeof error.code === "string" ? error.code.toLowerCase() : "";
  const name = typeof error.name === "string" ? error.name.toLowerCase() : "";
  const message = typeof error.message === "string" ? error.message.toLowerCase() : "";
  const status = Number(error.status ?? error.statusCode ?? 0);
  let classified;
  if (status === 429 || /rate.?limit|too many requests/.test(`${code} ${message}`)) {
    classified = "rate_limited";
  } else if (code === "user_banned" || /user.+banned|account.+banned/.test(message)) {
    classified = "user_banned";
  } else if (
    code === "refresh_token_not_found"
    || code === "refresh_token_already_used"
    || code === "session_not_found"
    || /refresh.+(not found|already used)|session.+unavailable/.test(message)
  ) {
    classified = "session_unavailable";
  } else if (
    code === "bad_jwt"
    || code === "invalid_jwt"
    || code === "jwt_expired"
    || /^pgrst30[12]$/.test(code)
    || /\bjwt\b.+(invalid|expired|rejected)/.test(message)
  ) {
    classified = "jwt_rejected";
  } else if (
    code === "invalid_credentials"
    || code === "invalid_grant"
    || /invalid.+(login|credentials)/.test(message)
  ) {
    classified = "invalid_credentials";
  } else if (
    code === "request_timeout"
    || name === "aborterror"
    || /\b(timeout|timed out)\b/.test(message)
  ) {
    classified = "request_timeout";
  } else if (
    name === "fetcherror"
    || code === "fetch_error"
    || /\b(network|fetch failed|connection unavailable)\b/.test(message)
  ) {
    classified = "client_unavailable";
  } else {
    classified = "auth_rejected";
  }
  requireCondition(SAFE_AUTH_CODES.has(classified), "auth_taxonomy_failure");
  return classified;
}

function assertSafeEvidenceLine(line) {
  requireCondition(
    /^[A-Za-z0-9_./:=|-]+$/.test(line) && !FORBIDDEN_EVIDENCE.test(line),
    "unsafe_evidence_rejected",
  );
  return line;
}

function parseJwtSessionId(accessToken) {
  try {
    const parts = accessToken.split(".");
    if (parts.length !== 3) return null;
    const payload = JSON.parse(Buffer.from(parts[1], "base64url").toString("utf8"));
    return typeof payload.session_id === "string" && payload.session_id.length > 0
      ? payload.session_id
      : null;
  } catch {
    return null;
  }
}

function targetSessionsAreDistinct(sessionB1, sessionB2) {
  if (
    typeof sessionB1?.refresh_token !== "string"
    || typeof sessionB2?.refresh_token !== "string"
    || sessionB1.refresh_token.length === 0
    || sessionB2.refresh_token.length === 0
    || sessionB1.refresh_token === sessionB2.refresh_token
  ) {
    return false;
  }
  const sessionIdB1 = parseJwtSessionId(sessionB1.access_token);
  const sessionIdB2 = parseJwtSessionId(sessionB2.access_token);
  return !(sessionIdB1 && sessionIdB2) || sessionIdB1 !== sessionIdB2;
}

function createIsolatedClient(projectUrl, publicKey) {
  return createClient(projectUrl, publicKey, CLIENT_OPTIONS);
}

function createBearerClient(projectUrl, publicKey, accessToken) {
  return createClient(projectUrl, publicKey, {
    ...CLIENT_OPTIONS,
    global: { headers: { Authorization: `Bearer ${accessToken}` } },
  });
}

function readRequiredFile(filePath, failureCode) {
  requireCondition(fs.existsSync(filePath), failureCode);
  return fs.readFileSync(filePath, "utf8").replace(/\r\n?/g, "\n");
}

function readSupabaseJsVersion(repoRoot) {
  let rootPackage;
  let installedPackage;
  try {
    rootPackage = JSON.parse(readRequiredFile(
      path.join(repoRoot, "package.json"),
      "root_package_missing",
    ));
    installedPackage = JSON.parse(readRequiredFile(
      path.join(repoRoot, "node_modules", "@supabase", "supabase-js", "package.json"),
      "supabase_js_package_missing",
    ));
  } catch (error) {
    if (error instanceof SafeFailure) throw error;
    fail("package_version_invalid");
  }
  const declared = rootPackage?.dependencies?.["@supabase/supabase-js"];
  const normalizedDeclared = typeof declared === "string"
    ? declared.replace(/^[~^]/, "")
    : "";
  requireCondition(
    normalizedDeclared === EXPECTED_SUPABASE_JS_VERSION
      && installedPackage?.version === EXPECTED_SUPABASE_JS_VERSION,
    "supabase_js_version_rejected",
  );
  return installedPackage.version;
}

function utcNow() {
  const value = new Date().toISOString();
  requireCondition(
    /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z$/.test(value),
    "utc_timestamp_invalid",
  );
  return value;
}

function operatorConfirmationOutcome(value) {
  return value === "CONTINUE_B3A_IRREVERSIBLE"
    ? { proceed: true, exitCode: 0 }
    : { proceed: false, exitCode: OPERATOR_ABORT_EXIT_CODE };
}

function rollbackEligibilityFromDiagnostic(parts) {
  if (!Array.isArray(parts) || parts.length !== 10 || parts[0] !== "B3A_FAILURE_DIAGNOSTIC") {
    return "UNKNOWN_DO_NOT_ROLLBACK";
  }
  const rawValues = parts.slice(1);
  if (!rawValues.every((value) => /^(0|[1-9]\d*)$/.test(value))) {
    return "UNKNOWN_DO_NOT_ROLLBACK";
  }
  const values = rawValues.map((value) => Number(value));
  if (values.some((value) => !Number.isInteger(value) || value < 0)) {
    return "UNKNOWN_DO_NOT_ROLLBACK";
  }
  const totalOperations = values[2];
  const totalAuthEvents = values[3];
  return totalOperations === 0 && totalAuthEvents === 0
    ? "STILL_AVAILABLE"
    : "REVOKED";
}

function sqlLiteralUuid(value) {
  requireCondition(UUID_PATTERN.test(value), "invalid_fixture_uuid");
  return `'${value}'::uuid`;
}

function sqlLiteralText(value) {
  requireCondition(typeof value === "string" && value.length > 0, "invalid_fixture_text");
  return `'${value.replace(/'/g, "''")}'::text`;
}

function expectedAccountsCte(adminA, adminB) {
  return `expected_accounts(id,email,first_names) as (values
    (${sqlLiteralUuid(adminA.id)},${sqlLiteralText(adminA.email)},${sqlLiteralText(EXPECTED_FIRST_NAMES.get("admin_a"))}),
    (${sqlLiteralUuid(adminB.id)},${sqlLiteralText(adminB.email)},${sqlLiteralText(EXPECTED_FIRST_NAMES.get("admin_b"))})
  )`;
}

function psqlEnvironment(dbUrl) {
  const environment = {};
  for (const [key, value] of Object.entries(process.env)) {
    if (!key.startsWith("SITAA_B3A_")) environment[key] = value;
  }
  environment.PGDATABASE = dbUrl;
  environment.PGCLIENTENCODING = "UTF8";
  return environment;
}

function runReadOnlySql(dbUrl, sql, expectedPrefix) {
  const normalized = sql.replace(/\r\n?/g, "\n").trim();
  requireCondition(/^begin;\nset transaction read only;/i.test(normalized), "sql_not_read_only");
  requireCondition(/\nrollback;$/i.test(normalized), "sql_missing_rollback");
  requireCondition(
    !/\b(insert|update|delete|alter|drop|truncate|grant|revoke|create|call|do)\b/i.test(
      normalized.replace(/'[^']*'/g, "''"),
    ),
    "sql_contains_write",
  );

  const result = spawnSync(
    "psql",
    ["-X", "-qAt", "-v", "ON_ERROR_STOP=1", "-f", "-"],
    {
      cwd: process.env.SITAA_B3A_REPO_ROOT,
      encoding: "utf8",
      env: psqlEnvironment(dbUrl),
      input: `${normalized}\n`,
      windowsHide: true,
      maxBuffer: 1024 * 1024,
    },
  );
  requireCondition(!result.error && result.status === 0, "readonly_database_check_failed");
  const lines = String(result.stdout ?? "")
    .replace(/\r\n?/g, "\n")
    .split("\n")
    .map((line) => line.trim())
    .filter(Boolean);
  const matches = lines.filter((line) => line.startsWith(`${expectedPrefix}|`));
  requireCondition(matches.length === 1, "readonly_database_result_invalid");
  return matches[0].split("|");
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
        if (
          characters.length === 0
          || characters.some((entry) => /[\p{Cc}\p{Cf}\p{Cs}]/u.test(entry))
        ) {
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

async function signInExact(client, email, password, expectedId, failureCode) {
  const result = await client.auth.signInWithPassword({ email, password });
  requireCondition(!result.error && result.data?.session && result.data?.user, failureCode);
  requireCondition(result.data.user.id === expectedId, "authenticated_user_mismatch");
  return result.data.session;
}

async function refreshExact(client, session, expectedId, failureCode) {
  requireCondition(typeof session.refresh_token === "string" && session.refresh_token.length > 0, failureCode);
  const result = await client.auth.refreshSession({ refresh_token: session.refresh_token });
  requireCondition(!result.error && result.data?.session && result.data?.user, failureCode);
  requireCondition(result.data.user.id === expectedId, "refreshed_user_mismatch");
  return result.data.session;
}

async function assertClientSession(client, expectedSession, failureCode) {
  const current = await client.auth.getSession();
  requireCondition(
    !current.error
      && current.data?.session?.access_token === expectedSession.access_token
      && current.data?.session?.refresh_token === expectedSession.refresh_token,
    failureCode,
  );
}

async function getUserObservation(client, accessToken, expectedId) {
  const result = await client.auth.getUser(accessToken);
  return {
    accepted: !result.error && result.data?.user?.id === expectedId,
    code: classifyAuthError(result.error),
  };
}

async function refreshObservation(client, session, expectedId) {
  const result = await client.auth.refreshSession({ refresh_token: session.refresh_token });
  const accepted = !result.error
    && result.data?.user?.id === expectedId
    && Boolean(result.data?.session);
  requireCondition(
    Boolean(result.error) || accepted,
    "refresh_observation_malformed",
  );
  return {
    accepted,
    code: classifyAuthError(result.error),
    session: accepted ? result.data.session : null,
  };
}

function signInObservation(result, expectedId) {
  const accepted = !result.error
    && result.data?.user?.id === expectedId
    && Boolean(result.data?.session);
  requireCondition(Boolean(result.error) || accepted, "login_observation_malformed");
  return {
    accepted,
    code: classifyAuthError(result.error),
    session: accepted ? result.data.session : null,
  };
}

async function protectedContext(projectUrl, publicKey, accessToken, targetId) {
  const client = createBearerClient(projectUrl, publicKey, accessToken);
  return client.rpc("get_admin_account_auth_lifecycle_context_b3a", {
    requested_profile_id: targetId,
  });
}

function contextIsAccessible(result, targetId) {
  const row = oneRow(result.data);
  return !result.error && row?.target_profile_id === targetId && row?.b3a_available === true;
}

function classifyOperationalBarrier(result, targetId) {
  if (!result.error) {
    return contextIsAccessible(result, targetId) ? "accessible" : "malformed_response";
  }
  const code = typeof result.error.code === "string"
    ? result.error.code.toLowerCase()
    : "";
  const message = typeof result.error.message === "string"
    ? result.error.message.toLowerCase()
    : "";
  const name = typeof result.error.name === "string"
    ? result.error.name.toLowerCase()
    : "";
  const status = Number(result.error.status ?? result.error.statusCode ?? 0);
  if (code === "42501" && message.includes("sitaa_admin_access_denied")) {
    return "database_inactive_denial";
  }
  if (
    code === "pgrst301"
    || code === "pgrst302"
    || code === "bad_jwt"
    || code === "invalid_jwt"
    || (status === 401 && /\b(jwt|authentication|authorization)\b/.test(message))
  ) {
    return "auth_gateway_denial";
  }
  if (
    name === "fetcherror"
    || code === "fetch_error"
    || /\b(network|fetch failed|connection unavailable|timed out|timeout)\b/.test(message)
  ) {
    return "transport_unavailable";
  }
  return "malformed_response";
}

function collectSuspendedAccessTokens({
  previousB1,
  previousB2,
  refreshedB1,
  refreshedB2,
  loginB1,
  loginB2,
}) {
  const candidates = [
    { source: "previous_b1", value: previousB1 },
    { source: "previous_b2", value: previousB2 },
  ];
  if (refreshedB1?.accepted && refreshedB1.session?.access_token) {
    candidates.push({ source: "refreshed_b1", value: refreshedB1.session.access_token });
  }
  if (refreshedB2?.accepted && refreshedB2.session?.access_token) {
    candidates.push({ source: "refreshed_b2", value: refreshedB2.session.access_token });
  }
  if (loginB1?.accepted && loginB1.session?.access_token) {
    candidates.push({ source: "login_b1", value: loginB1.session.access_token });
  }
  if (loginB2?.accepted && loginB2.session?.access_token) {
    candidates.push({ source: "login_b2", value: loginB2.session.access_token });
  }
  requireCondition(
    candidates.length >= 2
      && candidates.every((candidate) => typeof candidate.value === "string"
        && candidate.value.length > 0),
    "suspended_token_collection_invalid",
  );
  return candidates;
}

async function invokeTransition(client, targetId, transition, reason) {
  const requestId = crypto.randomUUID();
  const result = await client.functions.invoke("admin-account-auth-lifecycle", {
    body: {
      mode: "start",
      targetProfileId: targetId,
      transition,
      reason,
      requestId,
    },
  });
  requireCondition(!result.error, "edge_transition_failed");
  requireCondition(
    exactObject(result.data, ["code", "state", "operationId"]),
    "edge_response_malformed",
  );
  requireCondition(UUID_PATTERN.test(result.data.operationId), "edge_operation_id_invalid");
  return {
    requestId,
    operationId: result.data.operationId,
    code: result.data.code,
    state: result.data.state,
  };
}

function parseFixtureUsers(contents) {
  const rows = contents
    .split("\n")
    .map((line) => line.trim())
    .filter((line) => line.startsWith("AUTH_CREATED|"));
  requireCondition(rows.length === 2, "fixture_user_count_invalid");
  const users = new Map();
  for (const row of rows) {
    const fields = row.split("|");
    requireCondition(fields.length === 4, "fixture_user_shape_invalid");
    const [, alias, email, id] = fields;
    requireCondition(EXPECTED_EMAILS.has(alias) && !users.has(alias), "fixture_alias_invalid");
    requireCondition(email === EXPECTED_EMAILS.get(alias), "fixture_email_invalid");
    requireCondition(UUID_PATTERN.test(id), "fixture_uuid_invalid");
    users.set(alias, { email, id });
  }
  requireCondition(users.get("admin_a").id !== users.get("admin_b").id, "fixture_users_not_distinct");
  return users;
}

function lifecycleGateSql(adminAId, adminBId) {
  const ids = `${sqlLiteralUuid(adminAId)},${sqlLiteralUuid(adminBId)}`;
  const functionSignatureRows = B3A_FUNCTION_SIGNATURES
    .map((signature) => `(${sqlLiteralText(`public.${signature}`)})`)
    .join(",");
  const authActions = AUTH_ACTIONS.map((name) => `'${name}'`).join(",");
  return `
begin;
set transaction read only;
select concat_ws('|',
  'B3A_GATE',
  (select count(*) from auth.users),
  (select count(*) from auth.identities),
  (select count(*) from public.profiles),
  (select count(*) from public.role_assignments),
  (select count(*) from public.profiles p where p.id in (${ids})
    and public.is_exact_b1_account_admin_profile_b2b(p.id)),
  (select count(*) from public.admin_auth_operations),
  (select count(*) from public.admin_audit_events where action_code in (${authActions})),
  (select count(*) from (values ${functionSignatureRows}) expected(signature)
    where to_regprocedure(expected.signature) is not null),
  (select case when c.relrowsecurity then 1 else 0 end
    from pg_class c where c.oid='public.admin_auth_operations'::regclass),
  (select count(*) from pg_policies where schemaname='public'
    and tablename='admin_auth_operations'),
  (select count(*) from pg_trigger t
    where t.tgrelid='public.admin_auth_operations'::regclass
      and not t.tgisinternal and t.tgenabled='O'
      and t.tgfoid='public.guard_admin_auth_operation_b3a()'::regprocedure
      and t.tgname in ('guard_admin_auth_operation_b3a',
        'guard_admin_auth_operation_truncate_b3a')),
  (select count(*) from pg_trigger t
    where t.tgrelid='public.admin_auth_operations'::regclass and not t.tgisinternal)
);
rollback;`;
}

function baselineSql(adminA, adminB) {
  const target = sqlLiteralUuid(adminB.id);
  const ids = `${sqlLiteralUuid(adminA.id)},${target}`;
  const authActions = AUTH_ACTIONS.map((name) => `'${name}'`).join(",");
  return `
begin;
set transaction read only;
with ${expectedAccountsCte(adminA, adminB)}
select concat_ws('|',
  'B3A_BASELINE',
  coalesce((select activated_at::text from public.profiles where id=${target}),''),
  coalesce((select md5((to_jsonb(p)-'updated_at')::text)
    from public.profiles p where p.id=${target}),''),
  coalesce((select md5(coalesce(string_agg(to_jsonb(a)::text,'|' order by a.id),''))
    from public.role_assignments a where a.user_id in (${ids})),''),
  md5(
    coalesce((select string_agg(to_jsonb(a)::text,'|' order by a.id)
      from public.activities a),'')
    ||':'||
    coalesce((select string_agg(to_jsonb(p)::text,'|' order by p.id)
      from public.activity_participants p),'')
  ),
  (select count(*) from public.admin_auth_operations),
  (select count(*) from public.admin_audit_events),
  (select count(*) from public.admin_audit_events where action_code in (${authActions})),
  (select count(*) from auth.users),
  (select count(*) from auth.identities),
  (select count(*) from expected_accounts expected
    join auth.users auth_user
      on auth_user.id=expected.id
     and lower(btrim(auth_user.email))=expected.email
     and auth_user.email_confirmed_at is not null
     and auth_user.raw_app_meta_data->>'provider'='email'
     and auth_user.raw_app_meta_data->'providers'='["email"]'::jsonb
     and auth_user.raw_app_meta_data-'provider'-'providers'
       =jsonb_build_object(
         'sitaa_account_kind','technical',
         'sitaa_first_names',expected.first_names
       )
    where (select count(*) from auth.identities identity_row
      where identity_row.user_id=expected.id
        and identity_row.provider='email'
        and lower(btrim(identity_row.identity_data->>'email'))=expected.email)=1),
  (select count(*) from public.profiles profile
    where profile.id in (${ids})
      and profile.account_status='active' and profile.is_active
      and profile.activated_at is not null and profile.deactivated_at is null
      and public.is_exact_b1_account_admin_profile_b2b(profile.id))
);
rollback;`;
}

function deactivationSql(adminAId, adminBId, activatedAt, transition) {
  const actor = sqlLiteralUuid(adminAId);
  const target = sqlLiteralUuid(adminBId);
  const operationId = sqlLiteralUuid(transition.operationId);
  const requestId = sqlLiteralUuid(transition.requestId);
  const safeActivatedAt = activatedAt.replace(/'/g, "''");
  return `
begin;
set transaction read only;
select concat_ws('|',
  'B3A_DEACTIVATED',
  (select case when account_status='inactive' and not is_active
    and activated_at='${safeActivatedAt}'::timestamptz and deactivated_at is not null
    then 1 else 0 end from public.profiles where id=${target}),
  (select count(*) from auth.users
    where id=${target} and banned_until is not null
      and banned_until>clock_timestamp()),
  (select count(*) from public.admin_auth_operations
    where id=${operationId} and request_id=${requestId}
      and target_profile_id=${target} and requested_by_profile_id=${actor}
      and completed_by_profile_id=${actor} and operation_code='deactivate'
      and status='succeeded' and completed_stage='completed'
      and last_error_code is null and completed_at is not null),
  (select count(*) from public.admin_auth_operations),
  (select count(*) from public.admin_audit_events),
  (select count(*) from public.admin_audit_events
    where actor_profile_id=${actor} and target_profile_id=${target}
      and action_code='account_deactivated' and outcome='success'),
  (select count(*) from public.admin_audit_events
    where actor_profile_id=${actor} and target_profile_id=${target}
      and action_code='account_auth_suspended' and outcome='success'),
  (select case when bool_and(public.admin_audit_metadata_is_safe(metadata))
      and bool_and(metadata::text !~* '@|password|token|cookie|secret|authorization|bearer')
    then 1 else 0 end
    from public.admin_audit_events
    where actor_profile_id=${actor} and target_profile_id=${target}
      and action_code in ('account_deactivated','account_auth_suspended'))
);
rollback;`;
}

function restorationSql(adminA, adminB, deactivation, reactivation) {
  const actor = sqlLiteralUuid(adminA.id);
  const target = sqlLiteralUuid(adminB.id);
  const ids = `${actor},${target}`;
  const deactivationOperationId = sqlLiteralUuid(deactivation.operationId);
  const deactivationRequestId = sqlLiteralUuid(deactivation.requestId);
  const reactivationOperationId = sqlLiteralUuid(reactivation.operationId);
  const reactivationRequestId = sqlLiteralUuid(reactivation.requestId);
  return `
begin;
set transaction read only;
with ${expectedAccountsCte(adminA, adminB)}
select concat_ws('|',
  'B3A_RESTORED',
  (select case when account_status='active' and is_active
    and activated_at is not null and deactivated_at is null then 1 else 0 end
    from public.profiles where id=${target}),
  (select count(*) from auth.users
    where id=${target}
      and (banned_until is null or banned_until<=clock_timestamp())),
  (select md5((to_jsonb(p)-'updated_at')::text)
    from public.profiles p where p.id=${target}),
  (select md5(coalesce(string_agg(to_jsonb(a)::text,'|' order by a.id),''))
    from public.role_assignments a where a.user_id in (${ids})),
  md5(
    coalesce((select string_agg(to_jsonb(a)::text,'|' order by a.id)
      from public.activities a),'')
    ||':'||
    coalesce((select string_agg(to_jsonb(p)::text,'|' order by p.id)
      from public.activity_participants p),'')
  ),
  (select count(*) from public.admin_auth_operations
    where id=${deactivationOperationId} and request_id=${deactivationRequestId}
      and target_profile_id=${target} and requested_by_profile_id=${actor}
      and completed_by_profile_id=${actor} and status='succeeded'
      and completed_stage='completed' and operation_code='deactivate'
      and last_error_code is null and completed_at is not null),
  (select count(*) from public.admin_auth_operations
    where id=${reactivationOperationId} and request_id=${reactivationRequestId}
      and target_profile_id=${target} and requested_by_profile_id=${actor}
      and completed_by_profile_id=${actor} and status='succeeded'
      and completed_stage='completed' and operation_code='reactivate'
      and last_error_code is null and completed_at is not null),
  (select case when ${deactivationOperationId}<>${reactivationOperationId}
      and ${deactivationRequestId}<>${reactivationRequestId}
    then 1 else 0 end),
  (select count(*) from public.admin_auth_operations),
  (select count(*) from public.admin_audit_events),
  (select count(*) from public.admin_audit_events
    where actor_profile_id=${actor} and target_profile_id=${target}
      and action_code in ('account_deactivated','account_auth_suspended',
        'account_reactivated','account_auth_restored')
      and outcome='success'),
  (select count(distinct action_code) from public.admin_audit_events
    where actor_profile_id=${actor} and target_profile_id=${target}
      and action_code in ('account_deactivated','account_auth_suspended',
        'account_reactivated','account_auth_restored')
      and outcome='success'),
  (select case when bool_and(public.admin_audit_metadata_is_safe(metadata))
      and bool_and(metadata::text !~* '@|password|token|cookie|secret|authorization|bearer')
    then 1 else 0 end
    from public.admin_audit_events
    where actor_profile_id=${actor} and target_profile_id=${target}
      and action_code in ('account_deactivated','account_auth_suspended',
        'account_reactivated','account_auth_restored')),
  (select count(*) from auth.users),
  (select count(*) from auth.identities),
  (select count(*) from expected_accounts expected
    join auth.users auth_user
      on auth_user.id=expected.id
     and lower(btrim(auth_user.email))=expected.email
     and auth_user.email_confirmed_at is not null
     and auth_user.raw_app_meta_data->>'provider'='email'
     and auth_user.raw_app_meta_data->'providers'='["email"]'::jsonb
     and auth_user.raw_app_meta_data-'provider'-'providers'
       =jsonb_build_object(
         'sitaa_account_kind','technical',
         'sitaa_first_names',expected.first_names
       )
    where (select count(*) from auth.identities identity_row
      where identity_row.user_id=expected.id
        and identity_row.provider='email'
        and lower(btrim(identity_row.identity_data->>'email'))=expected.email)=1),
  (select count(*) from public.profiles profile
    where profile.id in (${ids})
      and profile.account_status='active' and profile.is_active
      and profile.activated_at is not null and profile.deactivated_at is null
      and public.is_exact_b1_account_admin_profile_b2b(profile.id))
);
rollback;`;
}

function finalPostcheckSql(adminA, adminB) {
  const actor = sqlLiteralUuid(adminA.id);
  const target = sqlLiteralUuid(adminB.id);
  const ids = `${actor},${target}`;
  return `
begin;
set transaction read only;
with ${expectedAccountsCte(adminA, adminB)}
select concat_ws('|',
  'B3A_CORE_POSTCHECK',
  (select count(*) from public.profiles where id=${target}
    and account_status='active' and is_active and deactivated_at is null),
  (select count(*) from auth.users
    where id=${target}
      and (banned_until is null or banned_until<=clock_timestamp())),
  (select count(*) from public.admin_auth_operations
    where target_profile_id=${target} and requested_by_profile_id=${actor}
      and completed_by_profile_id=${actor} and status='succeeded'
      and completed_stage='completed'),
  (select count(*) from public.admin_audit_events
    where actor_profile_id=${actor} and target_profile_id=${target}
      and action_code in ('account_deactivated','account_auth_suspended',
        'account_reactivated','account_auth_restored') and outcome='success'),
  (select count(*) from public.admin_auth_operations
    where target_profile_id=${target} and status<>'succeeded'),
  (select count(*) from public.admin_audit_events
    where target_profile_id=${target}
      and action_code in ('account_auth_suspension_failed','account_auth_restoration_failed')),
  (select count(*) from auth.users),
  (select count(*) from auth.identities),
  (select count(*) from expected_accounts expected
    join auth.users auth_user
      on auth_user.id=expected.id
     and lower(btrim(auth_user.email))=expected.email
     and auth_user.email_confirmed_at is not null
     and auth_user.raw_app_meta_data->>'provider'='email'
     and auth_user.raw_app_meta_data->'providers'='["email"]'::jsonb
     and auth_user.raw_app_meta_data-'provider'-'providers'
       =jsonb_build_object(
         'sitaa_account_kind','technical',
         'sitaa_first_names',expected.first_names
       )
    where (select count(*) from auth.identities identity_row
      where identity_row.user_id=expected.id
        and identity_row.provider='email'
        and lower(btrim(identity_row.identity_data->>'email'))=expected.email)=1),
  (select count(*) from public.profiles profile
    where profile.id in (${ids})
      and profile.account_status='active' and profile.is_active
      and profile.activated_at is not null and profile.deactivated_at is null
      and public.is_exact_b1_account_admin_profile_b2b(profile.id))
);
rollback;`;
}

function irreversibleDiagnosticSql(adminAId, adminBId) {
  const actor = sqlLiteralUuid(adminAId);
  const target = sqlLiteralUuid(adminBId);
  return `
begin;
set transaction read only;
select concat_ws('|',
  'B3A_FAILURE_DIAGNOSTIC',
  (select count(*) from public.profiles
    where id=${target} and account_status='active' and is_active),
  (select count(*) from public.profiles
    where id=${target} and account_status='inactive' and not is_active),
  (select count(*) from public.admin_auth_operations),
  (select count(*) from public.admin_audit_events
    where action_code in ('account_auth_suspended','account_auth_restored',
      'account_auth_suspension_failed','account_auth_restoration_failed')),
  (select count(*) from public.admin_auth_operations
    where target_profile_id=${target} and requested_by_profile_id=${actor}
      and status='succeeded' and completed_stage='completed'),
  (select count(*) from public.admin_auth_operations
    where status in ('open','processing','retryable_failure')),
  (select count(*) from public.admin_auth_operations
    where status='terminal_failure'),
  (select count(*) from public.admin_audit_events
    where actor_profile_id=${actor} and target_profile_id=${target}
      and action_code in ('account_deactivated','account_auth_suspended',
        'account_reactivated','account_auth_restored') and outcome='success'),
  (select count(*) from public.admin_audit_events
    where actor_profile_id=${actor} and target_profile_id=${target}
      and action_code in ('account_auth_suspension_failed',
        'account_auth_restoration_failed') and outcome='failure')
);
rollback;`;
}

function parseDelimited(parts, prefix, expectedLength) {
  requireCondition(parts[0] === prefix && parts.length === expectedLength, "database_contract_mismatch");
  return parts;
}

function runSelfTests() {
  const localSupabaseJsVersion = readSupabaseJsVersion(process.cwd());
  requireCondition(
    localSupabaseJsVersion === EXPECTED_SUPABASE_JS_VERSION,
    "supabase_js_version_fixture_failed",
  );
  const taxonomyCases = [
    [{ code: "refresh_token_not_found" }, "session_unavailable"],
    [{ code: "refresh_token_already_used" }, "session_unavailable"],
    [{ code: "weak_password" }, "auth_rejected"],
    [{ code: "user_banned" }, "user_banned"],
    [{ code: "bad_jwt" }, "jwt_rejected"],
    [{ code: "request_timeout" }, "request_timeout"],
    [{ status: 429, code: "over_request_rate_limit" }, "rate_limited"],
    [{ code: "invalid_credentials" }, "invalid_credentials"],
    [{ name: "FetchError", message: "fetch failed" }, "client_unavailable"],
    [null, "none"],
  ];
  for (const [fixture, expected] of taxonomyCases) {
    const classified = classifyAuthError(fixture);
    requireCondition(classified === expected && SAFE_AUTH_CODES.has(classified), "auth_taxonomy_fixture_failed");
    const evidence = assertSafeEvidenceLine(`AUTH_FIXTURE|code=${classified}`);
    const rawCode = typeof fixture?.code === "string" ? fixture.code.toLowerCase() : "";
    if (rawCode && !SAFE_AUTH_CODES.has(rawCode)) {
      requireCondition(!evidence.toLowerCase().includes(rawCode), "raw_auth_code_leaked");
    }
  }

  const targetId = "22222222-2222-4222-8222-222222222222";
  requireCondition(
    classifyOperationalBarrier({
      data: null,
      error: { code: "42501", message: "sitaa_admin_access_denied" },
    }, targetId) === "database_inactive_denial",
    "database_barrier_fixture_failed",
  );
  requireCondition(
    classifyOperationalBarrier({
      data: null,
      error: { code: "PGRST301", message: "JWT expired", status: 401 },
    }, targetId) === "auth_gateway_denial",
    "gateway_barrier_fixture_failed",
  );
  const transport = classifyOperationalBarrier({
    data: null,
    error: { name: "FetchError", message: "fetch failed" },
  }, targetId);
  requireCondition(
    transport === "transport_unavailable"
      && !new Set(["database_inactive_denial", "auth_gateway_denial"]).has(transport),
    "transport_barrier_fixture_failed",
  );

  const tokens = collectSuspendedAccessTokens({
    previousB1: "fixture-previous-b1",
    previousB2: "fixture-previous-b2",
    refreshedB1: {
      accepted: true,
      session: { access_token: "fixture-refreshed-b1" },
    },
    refreshedB2: { accepted: false, session: null },
    loginB1: { accepted: false, session: null },
    loginB2: {
      accepted: true,
      session: { access_token: "fixture-login-b2" },
    },
  });
  requireCondition(
    tokens.length === 4
      && tokens.map((entry) => entry.source).join("|")
        === "previous_b1|previous_b2|refreshed_b1|login_b2",
    "suspended_token_fixture_failed",
  );

  const adminA = {
    id: "11111111-1111-4111-8111-111111111111",
    email: EXPECTED_EMAILS.get("admin_a"),
  };
  const adminB = {
    id: targetId,
    email: EXPECTED_EMAILS.get("admin_b"),
  };
  const deactivation = {
    operationId: "33333333-3333-4333-8333-333333333333",
    requestId: "44444444-4444-4444-8444-444444444444",
  };
  const reactivation = {
    operationId: "55555555-5555-4555-8555-555555555555",
    requestId: "66666666-6666-4666-8666-666666666666",
  };
  const deactivationBuilder = deactivationSql(
    adminA.id,
    adminB.id,
    "2026-01-01T00:00:00+00:00",
    deactivation,
  );
  const restorationBuilder = restorationSql(adminA, adminB, deactivation, reactivation);
  for (const value of [
    deactivation.operationId,
    deactivation.requestId,
  ]) {
    requireCondition(deactivationBuilder.includes(`'${value}'::uuid`), "deactivation_sql_link_fixture_failed");
  }
  for (const value of [
    deactivation.operationId,
    deactivation.requestId,
    reactivation.operationId,
    reactivation.requestId,
  ]) {
    requireCondition(restorationBuilder.includes(`'${value}'::uuid`), "restoration_sql_link_fixture_failed");
  }
  requireCondition(
    restorationBuilder.includes("count(*) from public.admin_auth_operations")
      && restorationBuilder.includes("operation_code='deactivate'")
      && restorationBuilder.includes("operation_code='reactivate'")
      && deactivationBuilder.includes("banned_until>clock_timestamp()")
      && restorationBuilder.includes("banned_until<=clock_timestamp()"),
    "restoration_sql_contract_fixture_failed",
  );

  const gateBuilder = lifecycleGateSql(adminA.id, adminB.id);
  requireCondition(
    B3A_FUNCTION_SIGNATURES.every((signature) =>
      gateBuilder.includes(`'public.${signature}'::text`))
      && gateBuilder.includes("t.tgenabled='O'")
      && gateBuilder.includes("'guard_admin_auth_operation_b3a'")
      && gateBuilder.includes("'guard_admin_auth_operation_truncate_b3a'"),
    "inventory_gate_fixture_failed",
  );

  const aborted = operatorConfirmationOutcome("ABORT");
  requireCondition(
    !aborted.proceed && aborted.exitCode === OPERATOR_ABORT_EXIT_CODE,
    "operator_abort_fixture_failed",
  );
  requireCondition(
    operatorConfirmationOutcome("CONTINUE_B3A_IRREVERSIBLE").proceed,
    "operator_continue_fixture_failed",
  );

  const diagnosticBase = [
    "B3A_FAILURE_DIAGNOSTIC",
    "1", "0", "0", "0", "0", "0", "0", "0", "0",
  ];
  requireCondition(
    rollbackEligibilityFromDiagnostic(diagnosticBase) === "STILL_AVAILABLE",
    "rollback_available_fixture_failed",
  );
  const revokedDiagnostic = [...diagnosticBase];
  revokedDiagnostic[3] = "1";
  requireCondition(
    rollbackEligibilityFromDiagnostic(revokedDiagnostic) === "REVOKED",
    "rollback_revoked_fixture_failed",
  );
  requireCondition(
    rollbackEligibilityFromDiagnostic(["B3A_FAILURE_DIAGNOSTIC", "bad"])
      === "UNKNOWN_DO_NOT_ROLLBACK",
    "rollback_unknown_fixture_failed",
  );

  const evidenceMarkers = [
    `HARNESS_VERSION|${HARNESS_VERSION}`,
    `NODE_RUNTIME|${process.version}`,
    `SUPABASE_JS_VERSION|${localSupabaseJsVersion}`,
    "MATRIX_STARTED_UTC|2026-07-25T00:00:00.000Z",
    "DEACTIVATION_COMPLETED_UTC|2026-07-25T00:01:00.000Z",
    "REACTIVATION_COMPLETED_UTC|2026-07-25T00:02:00.000Z",
    "MATRIX_COMPLETED_UTC|2026-07-25T00:03:00.000Z",
    "ROLLBACK_0010_ELIGIBILITY|STILL_AVAILABLE",
    "ROLLBACK_0010_ELIGIBILITY|REVOKED",
    "ROLLBACK_0010_ELIGIBILITY|UNKNOWN_DO_NOT_ROLLBACK",
  ];
  requireCondition(
    evidenceMarkers.every((marker) => assertSafeEvidenceLine(marker) === marker),
    "version_evidence_fixture_failed",
  );

  console.log("B3A_HOSTED_AUTH_CORE_FIXTURES|APPROVED");
}

async function main() {
  runtimeState.phase = "before_confirmation";
  const matrixStartedUtc = utcNow();
  const repoRoot = path.resolve(process.env.SITAA_B3A_REPO_ROOT ?? "");
  requireCondition(repoRoot.length > 0 && process.cwd() === repoRoot, "repository_root_required");
  requireCondition(fs.existsSync(path.join(repoRoot, "package.json")), "repository_root_invalid");
  const supabaseJsVersion = readSupabaseJsVersion(repoRoot);

  const projectRef = process.env.SITAA_B3A_PROJECT_REF ?? "";
  const dbUrl = process.env.SITAA_B3A_DB_URL ?? "";
  requireCondition(projectRef === EXPECTED_PROJECT_REF, "project_ref_rejected");
  requireCondition(dbUrl.length > 0 && dbUrl.includes(EXPECTED_PROJECT_REF), "database_url_rejected");
  runtimeState.dbUrl = dbUrl;

  const reconciliationRoot = path.join(repoRoot, "supabase", "reconciliation");
  const coreEvidencePath = path.join(
    reconciliationRoot,
    "b3a_matrix_hosted_auth_core.local.txt",
  );
  const postcheckEvidencePath = path.join(
    reconciliationRoot,
    "b3a_matrix_hosted_auth_core_postcheck.local.txt",
  );
  requireCondition(
    !fs.existsSync(coreEvidencePath) && !fs.existsSync(postcheckEvidencePath),
    "new_evidence_already_exists",
  );
  runtimeState.evidencePath = coreEvidencePath;

  const approvals = [
    ["b3a_matrix_0010_apply.local.txt", "Disposable migration 0010: APPLIED"],
    ["b3a_matrix_0010_verify.local.txt", "Disposable verifier 0010: PASSED"],
    ["b3a_matrix_0010_postcheck.local.txt", "Migration and verifier 0010: APPROVED"],
    ["b3a_matrix_edge_function_deploy.local.txt", "EDGE_FUNCTION_POSTDEPLOY_STATE|ACTIVE"],
  ];
  for (const [fileName, marker] of approvals) {
    const contents = readRequiredFile(
      path.join(reconciliationRoot, fileName),
      "approval_evidence_missing",
    );
    requireCondition(contents.includes(marker), "approval_evidence_rejected");
    if (fileName === "b3a_matrix_0010_postcheck.local.txt") {
      requireCondition(contents.includes(EXPECTED_POSTCHECK), "postcheck_evidence_rejected");
    }
  }

  const users = parseFixtureUsers(
    readRequiredFile(
      path.join(reconciliationRoot, "b3a_matrix_hosted_auth_users.local.txt"),
      "fixture_users_missing",
    ),
  );
  const adminA = users.get("admin_a");
  const adminB = users.get("admin_b");
  runtimeState.adminAId = adminA.id;
  runtimeState.adminBId = adminB.id;

  const gate = parseDelimited(
    runReadOnlySql(dbUrl, lifecycleGateSql(adminA.id, adminB.id), "B3A_GATE"),
    "B3A_GATE",
    13,
  );
  requireCondition(
    gate.slice(1).join("|") === "2|2|2|2|2|0|0|6|1|0|2|2",
    "hosted_gate_rejected",
  );
  console.log("HOSTED_READ_ONLY_GATES|APPROVED");

  let publicKey = await readMasked("Publishable/anon key: ");
  let adminAPassword = await readMasked("Contraseña de Admin A: ");
  let adminBPassword = await readMasked("Contraseña de Admin B: ");
  requireCondition(publicKey.length > 0 && adminAPassword.length > 0 && adminBPassword.length > 0, "credentials_required");

  const adminAClient = createIsolatedClient(EXPECTED_PROJECT_URL, publicKey);
  const sessionB1Client = createIsolatedClient(EXPECTED_PROJECT_URL, publicKey);
  const sessionB2Client = createIsolatedClient(EXPECTED_PROJECT_URL, publicKey);

  let adminASession = await signInExact(
    adminAClient,
    adminA.email,
    adminAPassword,
    adminA.id,
    "admin_a_login_failed",
  );
  let sessionB1 = await signInExact(
    sessionB1Client,
    adminB.email,
    adminBPassword,
    adminB.id,
    "session_b1_login_failed",
  );
  let sessionB2 = await signInExact(
    sessionB2Client,
    adminB.email,
    adminBPassword,
    adminB.id,
    "session_b2_login_failed",
  );

  requireCondition(
    targetSessionsAreDistinct(sessionB1, sessionB2),
    "target_sessions_not_distinct",
  );

  sessionB1 = await refreshExact(
    sessionB1Client,
    sessionB1,
    adminB.id,
    "session_b1_base_refresh_failed",
  );
  sessionB2 = await refreshExact(
    sessionB2Client,
    sessionB2,
    adminB.id,
    "session_b2_base_refresh_failed",
  );
  const baseGetUserB1 = await getUserObservation(sessionB1Client, sessionB1.access_token, adminB.id);
  const baseGetUserB2 = await getUserObservation(sessionB2Client, sessionB2.access_token, adminB.id);
  requireCondition(baseGetUserB1.accepted && baseGetUserB2.accepted, "target_base_get_user_failed");
  const baseContext = await protectedContext(
    EXPECTED_PROJECT_URL,
    publicKey,
    sessionB1.access_token,
    adminB.id,
  );
  requireCondition(contextIsAccessible(baseContext, adminB.id), "target_base_rpc_denied");

  const baseline = parseDelimited(
    runReadOnlySql(dbUrl, baselineSql(adminA, adminB), "B3A_BASELINE"),
    "B3A_BASELINE",
    12,
  );
  const baselineState = {
    activatedAt: baseline[1],
    profileHash: baseline[2],
    assignmentsHash: baseline[3],
    operationalHash: baseline[4],
    ledgerCount: Number(baseline[5]),
    auditCount: Number(baseline[6]),
    authAuditCount: Number(baseline[7]),
    authUserCount: Number(baseline[8]),
    authIdentityCount: Number(baseline[9]),
    authContractCount: Number(baseline[10]),
    activeAuthorityCount: Number(baseline[11]),
  };
  requireCondition(
    baselineState.activatedAt.length > 0
      && /^[0-9a-f]{32}$/i.test(baselineState.profileHash)
      && /^[0-9a-f]{32}$/i.test(baselineState.assignmentsHash)
      && /^[0-9a-f]{32}$/i.test(baselineState.operationalHash)
      && baselineState.ledgerCount === 0
      && Number.isInteger(baselineState.auditCount)
      && baselineState.auditCount >= 0
      && baselineState.authAuditCount === 0
      && baselineState.authUserCount === 2
      && baselineState.authIdentityCount === 2
      && baselineState.authContractCount === 2
      && baselineState.activeAuthorityCount === 2,
    "baseline_database_state_rejected",
  );
  const evidence = [];
  let evidencePersisted = false;
  const record = (line) => {
    assertSafeEvidenceLine(line);
    console.log(line);
    evidence.push(line);
    if (evidencePersisted) fs.appendFileSync(coreEvidencePath, `${line}\n`, "utf8");
  };
  const persistEvidence = () => {
    fs.writeFileSync(coreEvidencePath, `${evidence.join("\n")}\n`, {
      encoding: "utf8",
      flag: "wx",
    });
    evidencePersisted = true;
    runtimeState.irreversibleEvidencePersisted = true;
  };

  record("ADMIN_A_BASE_LOGIN|true");
  record("TARGET_BASE_LOGIN|2/2");
  record("TARGET_BASE_GET_USER|2/2");
  record("TARGET_BASE_RPC|APPROVED");
  record("TARGET_SESSIONS_DISTINCT|true");
  record("TARGET_BASE_REFRESH|2/2");
  record(`HARNESS_VERSION|${HARNESS_VERSION}`);
  record(`NODE_RUNTIME|${process.version}`);
  record(`SUPABASE_JS_VERSION|${supabaseJsVersion}`);
  record(`MATRIX_STARTED_UTC|${matrixStartedUtc}`);
  record("AUTH_USERS|2");
  record("AUTH_IDENTITIES|2");
  record("AUTH_IDENTITY_CONTRACT|true");
  record("B1_ACTIVE_AUTHORITY|2/2");
  record("HOSTED_AUTH_BASELINE|APPROVED");
  record("REAL_B3A_OPERATION_COUNT|0");
  record("ROLLBACK_0010_ELIGIBILITY|STILL_AVAILABLE");
  record("WAITING_FOR_IRREVERSIBLE_CONFIRMATION");

  const prompt = readline.createInterface({ input: process.stdin, output: process.stdout });
  const confirmation = await prompt.question("> ");
  prompt.close();
  const confirmationOutcome = operatorConfirmationOutcome(confirmation);
  if (!confirmationOutcome.proceed) {
    console.log("HOSTED_AUTH_CORE_MATRIX|ABORTED");
    publicKey = "";
    adminAPassword = "";
    adminBPassword = "";
    adminASession = null;
    sessionB1 = null;
    sessionB2 = null;
    process.exitCode = confirmationOutcome.exitCode;
    return;
  }

  runtimeState.phase = "before_deactivation";
  adminASession = await refreshExact(
    adminAClient,
    adminASession,
    adminA.id,
    "admin_a_pre_deactivation_refresh_failed",
  );
  await assertClientSession(
    adminAClient,
    adminASession,
    "admin_a_pre_deactivation_session_mismatch",
  );
  sessionB1 = await refreshExact(
    sessionB1Client,
    sessionB1,
    adminB.id,
    "session_b1_pre_deactivation_refresh_failed",
  );
  sessionB2 = await refreshExact(
    sessionB2Client,
    sessionB2,
    adminB.id,
    "session_b2_pre_deactivation_refresh_failed",
  );
  await assertClientSession(
    sessionB1Client,
    sessionB1,
    "session_b1_pre_deactivation_session_mismatch",
  );
  await assertClientSession(
    sessionB2Client,
    sessionB2,
    "session_b2_pre_deactivation_session_mismatch",
  );
  requireCondition(
    targetSessionsAreDistinct(sessionB1, sessionB2),
    "target_pre_deactivation_sessions_not_distinct",
  );
  record("IRREVERSIBLE_CONFIRMATION|ACCEPTED");
  record("ADMIN_A_PRE_DEACTIVATION_REFRESH|APPROVED");
  record("TARGET_PRE_DEACTIVATION_REFRESH|2/2");
  record("TARGET_PRE_DEACTIVATION_SESSIONS_DISTINCT|true");
  persistEvidence();
  const deactivation = await invokeTransition(
    adminAClient,
    adminB.id,
    "deactivate",
    "Prueba hospedada desechable de suspensión coordinada B.3a",
  );
  requireCondition(
    deactivation.state === "completed"
      && deactivation.code === "account_deactivated",
    "deactivation_not_completed",
  );
  runtimeState.phase = "deactivated";
  record("ROLLBACK_0010_ELIGIBILITY|REVOKED");
  record("HOSTED_AUTH_DEACTIVATION|COMPLETED");
  record(`DEACTIVATION_COMPLETED_UTC|${utcNow()}`);

  const deactivated = parseDelimited(
    runReadOnlySql(
      dbUrl,
      deactivationSql(
        adminA.id,
        adminB.id,
        baselineState.activatedAt,
        deactivation,
      ),
      "B3A_DEACTIVATED",
    ),
    "B3A_DEACTIVATED",
    9,
  );
  requireCondition(
    deactivated[1] === "1"
      && deactivated[2] === "1"
      && deactivated[3] === "1"
      && deactivated[4] === "1"
      && Number(deactivated[5]) === baselineState.auditCount + 2
      && deactivated.slice(6).join("|") === "1|1|1",
    "deactivation_postcheck_rejected",
  );
  record("AUTH_BAN_ACTIVE|true");

  runtimeState.phase = "suspended_observations";
  const oldAccessB1 = sessionB1.access_token;
  const oldAccessB2 = sessionB2.access_token;
  const suspendedJwtB1 = await getUserObservation(sessionB1Client, oldAccessB1, adminB.id);
  const suspendedJwtB2 = await getUserObservation(sessionB2Client, oldAccessB2, adminB.id);
  record(`SUSPENDED_JWT|session_b1|accepted=${suspendedJwtB1.accepted}|code=${suspendedJwtB1.code}`);
  record(`SUSPENDED_JWT|session_b2|accepted=${suspendedJwtB2.accepted}|code=${suspendedJwtB2.code}`);
  record("HOSTED_AUTH_SUSPENDED_JWT_OBSERVATION|RECORDED");

  const suspendedRefreshB1 = await refreshObservation(sessionB1Client, sessionB1, adminB.id);
  const suspendedRefreshB2 = await refreshObservation(sessionB2Client, sessionB2, adminB.id);
  record(`SUSPENDED_REFRESH|session_b1|accepted=${suspendedRefreshB1.accepted}|code=${suspendedRefreshB1.code}`);
  record(`SUSPENDED_REFRESH|session_b2|accepted=${suspendedRefreshB2.accepted}|code=${suspendedRefreshB2.code}`);
  record("HOSTED_AUTH_SUSPENDED_REFRESH_OBSERVATION|RECORDED");

  const suspendedLoginClientB1 = createIsolatedClient(EXPECTED_PROJECT_URL, publicKey);
  const suspendedLoginClientB2 = createIsolatedClient(EXPECTED_PROJECT_URL, publicKey);
  const suspendedLoginB1 = await suspendedLoginClientB1.auth.signInWithPassword({
    email: adminB.email,
    password: adminBPassword,
  });
  const suspendedLoginB2 = await suspendedLoginClientB2.auth.signInWithPassword({
    email: adminB.email,
    password: adminBPassword,
  });
  const suspendedLoginObservationB1 = signInObservation(suspendedLoginB1, adminB.id);
  const suspendedLoginObservationB2 = signInObservation(suspendedLoginB2, adminB.id);
  record(`SUSPENDED_LOGIN|session_b1|accepted=${suspendedLoginObservationB1.accepted}|code=${suspendedLoginObservationB1.code}`);
  record(`SUSPENDED_LOGIN|session_b2|accepted=${suspendedLoginObservationB2.accepted}|code=${suspendedLoginObservationB2.code}`);
  record("HOSTED_AUTH_SUSPENDED_LOGIN_OBSERVATION|RECORDED");

  const suspendedTokens = collectSuspendedAccessTokens({
    previousB1: oldAccessB1,
    previousB2: oldAccessB2,
    refreshedB1: suspendedRefreshB1,
    refreshedB2: suspendedRefreshB2,
    loginB1: suspendedLoginObservationB1,
    loginB2: suspendedLoginObservationB2,
  });
  let approvedBarrierCount = 0;
  for (const candidate of suspendedTokens) {
    const result = await protectedContext(
      EXPECTED_PROJECT_URL,
      publicKey,
      candidate.value,
      adminB.id,
    );
    const observation = classifyOperationalBarrier(result, adminB.id);
    if (
      observation === "database_inactive_denial"
      || observation === "auth_gateway_denial"
    ) {
      approvedBarrierCount += 1;
    }
  }
  requireCondition(
    approvedBarrierCount === suspendedTokens.length,
    "inactive_operational_barrier_failed",
  );
  record(`SITAA_SUSPENDED_TOKENS_TESTED|${approvedBarrierCount}/${suspendedTokens.length}`);
  record("SITAA_ACTIVE_BARRIER_DURING_SUSPENSION|APPROVED");

  runtimeState.phase = "before_reactivation";
  adminASession = await refreshExact(
    adminAClient,
    adminASession,
    adminA.id,
    "admin_a_pre_reactivation_refresh_failed",
  );
  await assertClientSession(
    adminAClient,
    adminASession,
    "admin_a_pre_reactivation_session_mismatch",
  );
  record("ADMIN_A_PRE_REACTIVATION_REFRESH|APPROVED");
  const reactivation = await invokeTransition(
    adminAClient,
    adminB.id,
    "reactivate",
    "Prueba hospedada desechable de restauración coordinada B.3a",
  );
  requireCondition(
    reactivation.state === "completed"
      && reactivation.code === "account_reactivated",
    "reactivation_not_completed",
  );
  requireCondition(
    reactivation.operationId !== deactivation.operationId
      && reactivation.requestId !== deactivation.requestId,
    "transition_identifiers_not_distinct",
  );
  runtimeState.phase = "reactivated";
  record("HOSTED_AUTH_REACTIVATION|COMPLETED");
  record(`REACTIVATION_COMPLETED_UTC|${utcNow()}`);

  const restoredLoginClient = createIsolatedClient(EXPECTED_PROJECT_URL, publicKey);
  const restoredLogin = await signInExact(
    restoredLoginClient,
    adminB.email,
    adminBPassword,
    adminB.id,
    "restored_login_failed",
  );
  const restoredContext = await protectedContext(
    EXPECTED_PROJECT_URL,
    publicKey,
    restoredLogin.access_token,
    adminB.id,
  );
  requireCondition(contextIsAccessible(restoredContext, adminB.id), "restored_rpc_denied");

  const restoredRefreshInputB1 = suspendedRefreshB1.accepted
    ? suspendedRefreshB1.session
    : sessionB1;
  const restoredRefreshInputB2 = suspendedRefreshB2.accepted
    ? suspendedRefreshB2.session
    : sessionB2;
  const restoredRefreshB1 = await refreshObservation(
    sessionB1Client,
    restoredRefreshInputB1,
    adminB.id,
  );
  const restoredRefreshB2 = await refreshObservation(
    sessionB2Client,
    restoredRefreshInputB2,
    adminB.id,
  );
  requireCondition(
    typeof restoredRefreshB1.accepted === "boolean"
      && typeof restoredRefreshB2.accepted === "boolean",
    "restored_refresh_observation_failed",
  );
  record(`RESTORED_REFRESH|session_b1|accepted=${restoredRefreshB1.accepted}|code=${restoredRefreshB1.code}`);
  record(`RESTORED_REFRESH|session_b2|accepted=${restoredRefreshB2.accepted}|code=${restoredRefreshB2.code}`);
  record("HOSTED_AUTH_RESTORED_REFRESH_OBSERVATION|RECORDED");
  record("HOSTED_AUTH_RESTORED_LOGIN|APPROVED");

  const restored = parseDelimited(
    runReadOnlySql(
      dbUrl,
      restorationSql(adminA, adminB, deactivation, reactivation),
      "B3A_RESTORED",
    ),
    "B3A_RESTORED",
    18,
  );
  requireCondition(restored[1] === "1", "restored_profile_state_rejected");
  requireCondition(restored[2] === "1", "restored_auth_ban_not_cleared");
  requireCondition(restored[3] === baselineState.profileHash, "restored_profile_hash_changed");
  requireCondition(restored[4] === baselineState.assignmentsHash, "assignments_changed");
  requireCondition(restored[5] === baselineState.operationalHash, "operational_history_changed");
  requireCondition(
    restored.slice(6, 10).join("|") === "1|1|1|2"
      && Number(restored[10]) === baselineState.auditCount + 4
      && restored.slice(11).join("|") === "4|4|1|2|2|2|2",
    "restored_audit_state_rejected",
  );
  record("ACTIVATED_AT_PRESERVED|true");
  record("ASSIGNMENTS_PRESERVED|true");
  record("OPERATIONAL_HISTORY_PRESERVED|true");
  record("AUTH_IDENTITY_PRESERVED|true");
  record("B1_ACTIVE_AUTHORITY|2/2");
  record("AUTH_BAN_CLEARED|true");
  record("AUTH_AUDIT_SANITIZATION|APPROVED");

  runtimeState.phase = "final_postcheck";
  const finalPostcheck = parseDelimited(
    runReadOnlySql(dbUrl, finalPostcheckSql(adminA, adminB), "B3A_CORE_POSTCHECK"),
    "B3A_CORE_POSTCHECK",
    11,
  );
  requireCondition(
    finalPostcheck.slice(1).join("|") === "1|1|2|4|0|0|2|2|2|2",
    "final_postcheck_rejected",
  );
  const matrixCompletedUtc = utcNow();
  record(`MATRIX_COMPLETED_UTC|${matrixCompletedUtc}`);
  const postcheckLines = [
    "B3A_CORE_POSTCHECK|APPROVED",
    "READ_ONLY_TRANSACTION|true",
    "ROLLBACK|true",
    "PROFILE_ACTIVE|1",
    "AUTH_BAN_CLEARED|true",
    "COMPLETED_OPERATIONS|2",
    "EXPECTED_AUDIT_EVENTS|4",
    "NON_SUCCEEDED_OPERATIONS|0",
    "AUTH_FAILURE_EVENTS|0",
    "AUTH_USERS|2",
    "AUTH_IDENTITIES|2",
    "AUTH_IDENTITY_CONTRACT|true",
    "B1_ACTIVE_AUTHORITY|2/2",
    `MATRIX_COMPLETED_UTC|${matrixCompletedUtc}`,
  ];
  for (const line of postcheckLines) {
    requireCondition(!FORBIDDEN_EVIDENCE.test(line), "unsafe_postcheck_evidence_rejected");
  }
  fs.writeFileSync(postcheckEvidencePath, `${postcheckLines.join("\n")}\n`, {
    encoding: "utf8",
    flag: "wx",
  });
  record("HOSTED_AUTH_CORE_MATRIX|APPROVED");

  publicKey = "";
  adminAPassword = "";
  adminBPassword = "";
  adminASession = null;
  sessionB1 = null;
  sessionB2 = null;
  void suspendedJwtB1;
  void suspendedJwtB2;
}

function appendFailureEvidence(line) {
  assertSafeEvidenceLine(line);
  console.error(line);
  if (
    runtimeState.irreversibleEvidencePersisted
    && runtimeState.evidencePath
    && fs.existsSync(runtimeState.evidencePath)
  ) {
    fs.appendFileSync(runtimeState.evidencePath, `${line}\n`, "utf8");
  }
}

async function handleFailure(error) {
  const code = error instanceof SafeFailure ? error.code : "unexpected_failure";
  const safeCode = /^[a-z][a-z0-9_]{0,63}$/.test(code)
    && !FORBIDDEN_EVIDENCE.test(code)
    ? code
    : "unexpected_failure";
  appendFailureEvidence(`HOSTED_AUTH_CORE_MATRIX|REJECTED|${safeCode}`);
  if (runtimeState.irreversibleEvidencePersisted) {
    const phase = FAILURE_PHASES.has(runtimeState.phase)
      ? runtimeState.phase
      : "before_deactivation";
    appendFailureEvidence(`FAILURE_PHASE|${phase}`);
    try {
      const diagnostic = parseDelimited(
        runReadOnlySql(
          runtimeState.dbUrl,
          irreversibleDiagnosticSql(runtimeState.adminAId, runtimeState.adminBId),
          "B3A_FAILURE_DIAGNOSTIC",
        ),
        "B3A_FAILURE_DIAGNOSTIC",
        10,
      );
      const rollbackEligibility = rollbackEligibilityFromDiagnostic(diagnostic);
      requireCondition(
        rollbackEligibility !== "UNKNOWN_DO_NOT_ROLLBACK",
        "failure_diagnostic_shape_invalid",
      );
      appendFailureEvidence("FAILURE_DIAGNOSTIC|APPROVED");
      appendFailureEvidence(`DIAGNOSTIC_PROFILE_ACTIVE|${diagnostic[1]}`);
      appendFailureEvidence(`DIAGNOSTIC_PROFILE_INACTIVE|${diagnostic[2]}`);
      appendFailureEvidence(`DIAGNOSTIC_TOTAL_OPERATIONS|${diagnostic[3]}`);
      appendFailureEvidence(`DIAGNOSTIC_TOTAL_AUTH_EVENTS|${diagnostic[4]}`);
      appendFailureEvidence(`DIAGNOSTIC_SUCCEEDED_OPERATIONS|${diagnostic[5]}`);
      appendFailureEvidence(`DIAGNOSTIC_NONFINAL_OPERATIONS|${diagnostic[6]}`);
      appendFailureEvidence(`DIAGNOSTIC_TERMINAL_FAILURE_OPERATIONS|${diagnostic[7]}`);
      appendFailureEvidence(`DIAGNOSTIC_EXPECTED_EVENTS|${diagnostic[8]}`);
      appendFailureEvidence(`DIAGNOSTIC_FAILED_EVENTS|${diagnostic[9]}`);
      appendFailureEvidence("DIAGNOSTIC_READ_ONLY_ROLLBACK|true");
      appendFailureEvidence(`ROLLBACK_0010_ELIGIBILITY|${rollbackEligibility}`);
    } catch {
      appendFailureEvidence("FAILURE_DIAGNOSTIC|UNAVAILABLE");
      appendFailureEvidence(
        "ROLLBACK_0010_ELIGIBILITY|UNKNOWN_DO_NOT_ROLLBACK",
      );
    }
  }
  process.exitCode = 1;
}

if (process.argv.includes("--self-test")) {
  try {
    runSelfTests();
  } catch {
    console.error("B3A_HOSTED_AUTH_CORE_FIXTURES|REJECTED");
    process.exitCode = 1;
  }
} else {
  main().catch(handleFailure);
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

  # Windows PowerShell 5.1 usa el BOM para decodificar Get-Content correctamente.
  $legacyText = Get-Content -Raw -LiteralPath $PSCommandPath
  foreach ($literal in @(
      "Contraseña",
      "suspensión",
      "restauración",
      "aprobación"
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

try {
  if ($currentRoot -ne $repoRoot) {
    throw "Ejecuta el arnés desde la raíz del repositorio."
  }

  Assert-ScriptEncoding
  Assert-TemporaryPath -Candidate $temporaryRoot
  [System.IO.Directory]::CreateDirectory($temporaryRoot) | Out-Null
  try {
    [System.IO.File]::SetAttributes(
      $temporaryRoot,
      [System.IO.FileAttributes]::Directory -bor [System.IO.FileAttributes]::Hidden
    )
  }
  catch {
    # El prefijo con punto mantiene el directorio oculto en entornos no Windows.
  }
  [System.IO.File]::WriteAllText(
    $nodeModulePath,
    $nodeModule,
    [System.Text.UTF8Encoding]::new($false)
  )

  if ($ValidateOnly) {
    & node --check $nodeModulePath
    if ($LASTEXITCODE -ne 0) {
      throw "La validación sintáctica del módulo Node falló."
    }
    & node $nodeModulePath --self-test
    if ($LASTEXITCODE -ne 0) {
      throw "Las fixtures locales del módulo Node fallaron."
    }
    Write-Output "B3A_HOSTED_AUTH_CORE_STATIC_VALIDATION|APPROVED"
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

  $env:SITAA_B3A_REPO_ROOT = $repoRoot
  & node $nodeModulePath
  $nodeExitCode = $LASTEXITCODE
  if ($nodeExitCode -eq 2) {
    exit 2
  }
  if ($nodeExitCode -ne 0) {
    throw "El arnés terminó sin aprobación."
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
