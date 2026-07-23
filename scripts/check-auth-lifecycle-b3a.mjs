import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";

const root = process.cwd();
const read = (relative) => fs.readFileSync(path.join(root, relative), "utf8");
const edge = read("supabase/functions/admin-account-auth-lifecycle/index.ts");
const adapter = read("supabase/functions/admin-account-auth-lifecycle/auth-admin-adapter.ts");
const config = read("supabase/config.toml");
const migration = read("supabase/migrations/0010_coordinated_auth_session_suspension.sql");
const data = read("lib/admin/account-lifecycle.ts");
const action = read("app/admin/accounts/[id]/lifecycle/actions.ts");
const form = read("app/admin/accounts/[id]/lifecycle/account-lifecycle-form.tsx");
const envExample = read(".env.example");

assert.match(config, /\[functions\.admin-account-auth-lifecycle\][\s\S]*verify_jwt\s*=\s*true/);
assert.doesNotMatch(config, /verify_jwt\s*=\s*false/);
assert.match(edge, /request\.method !== "POST"/);
assert.match(edge, /userClient\.auth\.getUser\(token\)/);
assert.match(edge, /const actorProfileId = verifiedUser\.user\.id/);
assert.doesNotMatch(edge, /body\.(?:actor|actorId|actorProfileId|callerProfileId)/);
assert.match(edge, /persistSession: false/);
assert.match(edge, /autoRefreshToken: false/);
assert.match(edge, /detectSessionInUrl: false/);
assert.doesNotMatch(edge, /auth\.admin\.signOut/);
assert.doesNotMatch(edge, /console\.(?:log|info|error)\([^\n]*(?:reason|targetProfileId|actorProfileId|authorization|token)/i);
assert.match(adapter, /AUTH_RESTORATION_BAN_DURATION = "none"/);
assert.match(adapter, /AUTH_SUSPENSION_BAN_DURATION = "876000h"/);
assert.match(adapter, /auth\.admin\.updateUserById/);
assert.doesNotMatch(adapter, /throw error|error\.message|JSON\.stringify\(error/);
assert.doesNotMatch(adapter, /result:\s*"terminal_failure"/);
for (const status of ["400", "401", "403", "404", "422"]) {
  assert.ok(adapter.includes(`status === ${status}`), `Falta clasificación provisional HTTP ${status}`);
}
assert.match(edge, /function parseSnapshot/);
assert.match(edge, /function parseClaim/);
assert.match(edge, /function parseFinalization/);
assert.match(edge, /function exactSingleRow/);
assert.equal((edge.match(/\.rpc\("record_admin_auth_operation_result_b3a"/g) ?? []).length, 1);
assert.match(edge, /claimed_attempt_count:\s*operation\.attemptCount/);
assert.match(edge, /attemptCount:\s*operation\.attemptCount/);
assert.match(edge, /replayed\.claimed[\s\S]*replayed\.status !== "processing"[\s\S]*replayed\.completedStage !== "auth_synchronized"/);
assert.match(edge, /if \(error\) return \{ kind: recordResultCondition\(error\) \}/);
assert.match(edge, /kind: "authorization_lost"/);
assert.match(edge, /kind: "stale_attempt"/);
assert.match(edge, /kind: "state_conflict"/);
assert.match(edge, /kind: "malformed_response"/);
assert.match(edge, /kind: "unavailable"/);
assert.match(edge, /finalResponse\(operation\)/);
assert.match(edge, /completedStage === "auth_synchronized"/);
assert.match(data, /EDGE_COMPLETED_CODES/);
assert.match(data, /EDGE_TERMINAL_CODES/);
assert.match(data, /EDGE_PENDING_WITH_OPERATION_CODES/);
assert.match(data, /EDGE_PENDING_WITHOUT_OPERATION_CODES/);
assert.match(data, /EDGE_REJECTED_CODES/);
assert.match(action, /result\.state === "rejected" \? "error" : "pending"/);
assert.match(action, /result\.code === \(values\.transition === "deactivate" \? "account_deactivated" : "account_reactivated"\)/);
assert.match(data, /FunctionsHttpError/);
assert.match(data, /FunctionsRelayError/);
assert.match(data, /FunctionsFetchError/);
assert.match(data, /error instanceof FunctionsHttpError/);
assert.equal((data.match(/await error\.context\.json\(\)/g) ?? []).length, 1);
assert.match(data, /parseEdgeResult\(data\)/);
assert.match(data, /parseEdgeResult\(httpBody\)/);
assert.match(data, /error instanceof FunctionsRelayError \|\| error instanceof FunctionsFetchError/);
const edgeInvocationStart = data.indexOf("export async function runAdminAccountAuthLifecycle");
assert.ok(edgeInvocationStart >= 0);
const edgeInvocationBody = data.slice(edgeInvocationStart);
assert.doesNotMatch(edgeInvocationBody, /error\.message|error\.context\.text|error\.context\.headers/);
assert.match(action, /if \(context\.b3aAvailable\)[\s\S]*runAdminAccountAuthLifecycle[\s\S]*else \{[\s\S]*transitionAdminAccountLifecycleLegacyBeforeB3a/);
assert.match(action, /const nextValues = result\.operationId[\s\S]*: values/);

const fixtureCompletedCodes = new Set(["account_deactivated", "account_reactivated"]);
const fixtureTerminalCodes = new Set([
  "auth_user_not_found", "auth_update_rejected", "unsupported_auth_contract",
  "operation_terminal_failure",
]);
const fixturePendingWithOperationCodes = new Set([
  "auth_temporarily_unavailable", "auth_rate_limited", "auth_user_not_found",
  "auth_update_rejected", "unsupported_auth_contract", "database_finalize_pending",
  "operation_processing", "operation_unavailable", "authorization_lost",
  "state_conflict", "database_contract_rejected", "malformed_database_response",
  "result_persistence_failed",
]);
const fixturePendingWithoutOperationCodes = new Set([
  "trusted_boundary_unavailable", "malformed_database_response", "unexpected_failure",
]);
const fixtureRejectedCodes = new Set([
  "method_not_allowed", "invalid_content_type", "request_too_large",
  "authentication_required", "invalid_json", "invalid_request", "invalid_reason",
  "invalid_mode", "authorization_lost", "request_id_conflict", "pending_target",
  "operation_in_progress", "state_conflict", "database_contract_rejected",
]);
const fixtureUuidPattern = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const fixtureUuid = "11111111-1111-4111-8111-111111111111";
function parseFixtureEdgeResult(value) {
  if (typeof value !== "object" || value === null || Array.isArray(value)
    || Object.keys(value).length !== 3
    || Object.keys(value).some((key) => !["code", "state", "operationId"].includes(key))
    || typeof value.code !== "string" || typeof value.state !== "string") return null;
  if (value.state === "completed" && fixtureCompletedCodes.has(value.code)
    && fixtureUuidPattern.test(value.operationId)) return value;
  if (value.state === "terminal_failure" && fixtureTerminalCodes.has(value.code)
    && fixtureUuidPattern.test(value.operationId)) return value;
  if (value.state === "pending") {
    if (fixtureUuidPattern.test(value.operationId)
      && fixturePendingWithOperationCodes.has(value.code)) return value;
    if (value.operationId === null
      && fixturePendingWithoutOperationCodes.has(value.code)) return value;
  }
  if (value.state === "rejected" && value.operationId === null
    && fixtureRejectedCodes.has(value.code)) return value;
  return null;
}
function resolveFixtureInvocation({ data: fixtureData, errorKind, httpBody }) {
  if (!errorKind) {
    const parsed = parseFixtureEdgeResult(fixtureData);
    if (!parsed) throw new Error("unavailable");
    return parsed;
  }
  if (errorKind === "http") {
    const parsed = parseFixtureEdgeResult(httpBody);
    if (!parsed) throw new Error("trusted_boundary_unavailable");
    return parsed;
  }
  throw new Error("trusted_boundary_unavailable");
}
function canRedirectFixture(result, transition) {
  return result?.state === "completed"
    && result.operationId !== null
    && result.code === (transition === "deactivate" ? "account_deactivated" : "account_reactivated");
}
const validFixtures = [
  { data: { code: "account_deactivated", state: "completed", operationId: fixtureUuid },
    transition: "deactivate", expectedCode: "account_deactivated" },
  { data: { code: "account_reactivated", state: "completed", operationId: fixtureUuid },
    transition: "reactivate", expectedCode: "account_reactivated" },
  { errorKind: "http", httpBody: { code: "request_id_conflict", state: "rejected", operationId: null },
    transition: "deactivate", expectedCode: "request_id_conflict" },
  { errorKind: "http", httpBody: { code: "pending_target", state: "rejected", operationId: null },
    transition: "deactivate", expectedCode: "pending_target" },
  { errorKind: "http", httpBody: { code: "authorization_lost", state: "pending", operationId: fixtureUuid },
    transition: "deactivate", expectedCode: "authorization_lost" },
  { data: { code: "operation_processing", state: "pending", operationId: fixtureUuid },
    transition: "deactivate", expectedCode: "operation_processing" },
  { data: { code: "trusted_boundary_unavailable", state: "pending", operationId: null },
    transition: "deactivate", expectedCode: "trusted_boundary_unavailable" },
  { data: { code: "operation_terminal_failure", state: "terminal_failure", operationId: fixtureUuid },
    transition: "deactivate", expectedCode: "operation_terminal_failure" },
  { errorKind: "http", httpBody: { code: "authentication_required", state: "rejected", operationId: null },
    transition: "deactivate", expectedCode: "authentication_required" },
];
for (const fixture of validFixtures) {
  assert.equal(resolveFixtureInvocation(fixture).code, fixture.expectedCode);
}
const invalidFixtures = [
  { data: { code: "authorization_lost", state: "completed", operationId: fixtureUuid }, transition: "deactivate" },
  { data: { code: "account_deactivated", state: "completed", operationId: null }, transition: "deactivate" },
  { data: { code: "account_deactivated", state: "pending", operationId: fixtureUuid }, transition: "deactivate" },
  { data: { code: "account_reactivated", state: "completed", operationId: fixtureUuid }, transition: "deactivate" },
  { errorKind: "http", httpBody: { code: "request_id_conflict", state: "rejected", operationId: fixtureUuid }, transition: "deactivate" },
  { data: { code: "operation_processing", state: "pending", operationId: null }, transition: "deactivate" },
  { data: { code: "operation_terminal_failure", state: "terminal_failure", operationId: null }, transition: "deactivate" },
  { data: { code: "unknown_code", state: "pending", operationId: fixtureUuid }, transition: "deactivate" },
  { data: { code: "account_deactivated", state: "unknown_state", operationId: fixtureUuid }, transition: "deactivate" },
  { errorKind: "http", httpBody: { code: "request_id_conflict", state: "rejected", operationId: null, detail: "raw" }, transition: "deactivate" },
];
for (const fixture of invalidFixtures) {
  let parsed = null;
  try {
    parsed = resolveFixtureInvocation(fixture);
  } catch {
    // La falla cerrada del parser también impide cualquier redirección.
  }
  assert.equal(canRedirectFixture(parsed, fixture.transition), false);
}
assert.equal(validFixtures.filter((fixture) =>
  canRedirectFixture(resolveFixtureInvocation(fixture), fixture.transition)).length, 2);
for (const errorKind of ["relay", "fetch", "unknown"]) {
  assert.throws(() => resolveFixtureInvocation({ errorKind }), /trusted_boundary_unavailable/);
}

for (const secret of ["SUPABASE_SERVICE_ROLE_KEY", "SUPABASE_SECRET_KEY", "sb_secret_"]) {
  assert.equal(envExample.includes(secret), false, `${secret} no puede aparecer en .env.example`);
}
for (const directory of ["app", "components", "lib"]) {
  const stack = [path.join(root, directory)];
  while (stack.length) {
    const current = stack.pop();
    for (const entry of fs.readdirSync(current, { withFileTypes: true })) {
      const full = path.join(current, entry.name);
      if (entry.isDirectory()) stack.push(full);
      else if (/\.(?:ts|tsx|js|jsx|mjs)$/.test(entry.name)) {
        const source = fs.readFileSync(full, "utf8");
        assert.doesNotMatch(source, /SUPABASE_(?:SERVICE_ROLE|SECRET)_KEY|sb_secret_/i, `Secreto privilegiado fuera de Edge Function: ${full}`);
        assert.doesNotMatch(source, /auth\.admin\.|service[_-]?role.*createClient|createClient\([^)]*service/i, `Cliente privilegiado Next.js: ${full}`);
      }
    }
  }
}

assert.match(data, /import "server-only"/);
assert.match(action, /runAdminAccountAuthLifecycle/);
assert.match(data, /supabase\.functions\.invoke\("admin-account-auth-lifecycle"/);
assert.equal((`${data}\n${action}\n${form}`.match(/transition_admin_account_lifecycle_b2b/g) ?? []).length, 1);
assert.match(data, /transitionAdminAccountLifecycleLegacyBeforeB3a/);
assert.match(data, /if \(!isMissingRpc\(b3a\.error, "get_admin_account_auth_lifecycle_context_b3a"\)\) throw mappedError/);
assert.doesNotMatch(form, /createSupabase|functions\.invoke|auth\.admin/);
assert.match(action, /request_id/);
assert.match(form, /Reintentar sincronización/);
assert.match(form, /JWT de acceso ya emitidos pueden conservar validez técnica hasta expirar/);
assert.match(data, /current_operation_id/);
assert.doesNotMatch(`${data}\n${form}`, /openOperationId|open_operation_id/);

for (const value of ["open", "processing", "retryable_failure", "succeeded", "terminal_failure",
  "prepared", "profile_suspended", "auth_synchronized", "completed"]) assert.ok(migration.includes(`'${value}'`));
for (const rpc of ["get_admin_account_auth_lifecycle_context_b3a", "prepare_admin_account_auth_lifecycle_b3a",
  "finalize_admin_account_auth_reactivation_b3a", "claim_admin_auth_operation_b3a",
  "record_admin_auth_operation_result_b3a"]) assert.ok(migration.includes(rpc));
assert.match(migration, /admin_auth_operations_one_nonfinal_target_uidx/);
assert.match(migration, /revoke all on function public\.transition_admin_account_lifecycle_b2b[\s\S]*from public,anon,authenticated,service_role/);
assert.doesNotMatch(`${edge}\n${adapter}\n${action}\n${data}`, /immediate access-token invalidation|global sign-out|revoca(?:r|ción) criptográficamente/i);

console.log("Límite confiable Auth B.3a: OK");
console.log(`Fixtures Edge válidos aceptados: ${validFixtures.length}`);
console.log(`Fixtures Edge inválidos sin redirección: ${invalidFixtures.length}`);
console.log("Contrato discriminado Edge y coincidencia transición/código: OK");
console.log("Errores HTTP malformados, Relay, Fetch y desconocidos fallan cerrados: OK");
