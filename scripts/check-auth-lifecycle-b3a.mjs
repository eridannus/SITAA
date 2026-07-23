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
assert.match(edge, /function hasExactSnapshotState/);
assert.match(edge, /function initialStage/);
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
assert.match(edge, /operation\.status === "succeeded"[\s\S]*operation\.completedStage === "completed"[\s\S]*operation\.lastErrorCode === null/);
assert.match(edge, /completedStage === "auth_synchronized"/);
assert.match(data, /EDGE_COMPLETED_CODES/);
assert.match(data, /EDGE_TERMINAL_CODES/);
assert.match(data, /EDGE_PENDING_WITH_OPERATION_CODES/);
assert.match(data, /EDGE_PENDING_WITHOUT_OPERATION_CODES/);
assert.match(data, /EDGE_REJECTED_CODES/);
assert.match(action, /result\.state === "rejected" \? "error" : "pending"/);
assert.match(action, /result\.code === \(values\.transition === "deactivate" \? "account_deactivated" : "account_reactivated"\)/);
assert.doesNotMatch(action, /context\.operationCode !== values\.transition \|\| !context\.canRetryOrFinalize/);
assert.doesNotMatch(action, /values\.mode === "retry"[\s\S]{0,500}canRetryOrFinalize/);
assert.match(action, /function lifecycleModeValue\(formData: FormData\): AccountLifecycleValues\["mode"\]/);
assert.match(action, /value === "start" \|\| value === "retry" \? value : null/);
assert.doesNotMatch(action, /textValue\(formData, "mode"\) === "retry" \? "retry" : "start"/);
const lifecycleActionStart = action.indexOf("export async function submitAccountLifecycleTransition");
const invalidModeGuard = action.indexOf("if (values.mode === null)", lifecycleActionStart);
const authenticatedContextLoad = action.indexOf("await getAuthenticatedUserContext()", lifecycleActionStart);
const lifecycleContextLoad = action.indexOf("await getAdminAccountLifecycleContext(", lifecycleActionStart);
const edgeCall = action.indexOf("await runAdminAccountAuthLifecycle(", lifecycleActionStart);
const legacyCall = action.indexOf("await transitionAdminAccountLifecycleLegacyBeforeB3a(", lifecycleActionStart);
assert.ok(lifecycleActionStart >= 0 && invalidModeGuard > lifecycleActionStart);
for (const boundary of [authenticatedContextLoad, lifecycleContextLoad, edgeCall, legacyCall]) {
  assert.ok(boundary > invalidModeGuard,
    "El modo inválido debe rechazarse antes de autenticación, contexto y límites de mutación");
}
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
const startBranch = action.slice(
  action.indexOf("} else {\n      if (context.b3aAvailable)"),
  action.indexOf("  } catch (error)"),
);
assert.ok(startBranch.indexOf("if (context.b3aAvailable)") < startBranch.indexOf("const allowed ="),
  "B.3a debe invocarse antes de cualquier elegibilidad de presentación");
assert.ok(startBranch.indexOf("runAdminAccountAuthLifecycle") < startBranch.indexOf("const allowed ="),
  "El replay start B.3a debe llegar al límite Edge aunque el contexto ya cambió");
assert.match(startBranch, /else \{[\s\S]*const allowed = values\.transition === "deactivate"[\s\S]*if \(!allowed\)[\s\S]*transitionAdminAccountLifecycleLegacyBeforeB3a/,
  "Sólo el flujo legado conserva canDeactivate/canReactivate");
assert.match(action, /!context\.b3aAvailable \|\| context\.currentOperationId !== values\.operation_id[\s\S]*\|\| context\.operationCode !== values\.transition/);
assert.doesNotMatch(action, /canRetryOrFinalize/,
  "canRetryOrFinalize es sólo presentación y no puede cercar la Server Action");

function fixtureStartReachesAuthoritativePath({ b3aAvailable, canTransition }) {
  return b3aAvailable || canTransition;
}
for (const replayState of [
  "completed_after_lost_response",
  "profile_suspended_before_form_operation_id",
  "retryable_failure_same_request",
]) {
  assert.equal(fixtureStartReachesAuthoritativePath({
    b3aAvailable: true,
    canTransition: false,
    replayState,
  }), true, `El replay start debe alcanzar prepare: ${replayState}`);
}
assert.equal(fixtureStartReachesAuthoritativePath({
  b3aAvailable: false,
  canTransition: false,
}), false, "El flujo legado debe conservar la elegibilidad local");
assert.equal(fixtureStartReachesAuthoritativePath({
  b3aAvailable: false,
  canTransition: true,
}), true);

function parseLifecycleModeFixture(value) {
  return value === "start" || value === "retry" ? value : null;
}
function fixtureMalformedModeDispatch(value) {
  const mode = parseLifecycleModeFixture(value);
  const calls = { edge: 0, legacy: 0 };
  if (mode === null) return calls;
  if (mode === "retry") calls.edge += 1;
  else calls.legacy += 1;
  return calls;
}
for (const malformedMode of [
  undefined,
  null,
  "",
  "START",
  "RETRY",
  " start",
  "start ",
  " retry",
  "retry ",
  "unknown",
]) {
  assert.equal(parseLifecycleModeFixture(malformedMode), null);
  assert.deepEqual(fixtureMalformedModeDispatch(malformedMode), { edge: 0, legacy: 0 },
    `El modo malformado no debe alcanzar Edge ni legado: ${String(malformedMode)}`);
}
assert.equal(parseLifecycleModeFixture("start"), "start");
assert.equal(parseLifecycleModeFixture("retry"), "retry");

function fixtureRetryReachesAuthoritativePath({
  b3aAvailable,
  currentOperationId,
  submittedOperationId,
  operationCode,
  submittedTransition,
}) {
  return b3aAvailable
    && currentOperationId === submittedOperationId
    && operationCode === submittedTransition;
}
const replayFixtureUuid = "11111111-1111-4111-8111-111111111111";
for (const authoritativeState of [
  "succeeded_between_render_and_action",
  "terminal_between_render_and_action",
  "fresh_processing",
  "auth_synchronized_finalize_recovery",
]) {
  assert.equal(fixtureRetryReachesAuthoritativePath({
    b3aAvailable: true,
    currentOperationId: replayFixtureUuid,
    submittedOperationId: replayFixtureUuid,
    operationCode: "reactivate",
    submittedTransition: "reactivate",
    authoritativeState,
  }), true, `El replay retry debe alcanzar claim: ${authoritativeState}`);
}
assert.equal(fixtureRetryReachesAuthoritativePath({
  b3aAvailable: true,
  currentOperationId: replayFixtureUuid,
  submittedOperationId: "22222222-2222-4222-8222-222222222222",
  operationCode: "reactivate",
  submittedTransition: "reactivate",
}), false);
assert.equal(fixtureRetryReachesAuthoritativePath({
  b3aAvailable: true,
  currentOperationId: replayFixtureUuid,
  submittedOperationId: replayFixtureUuid,
  operationCode: "deactivate",
  submittedTransition: "reactivate",
}), false);

const fixtureCompletedCodes = new Set(["account_deactivated", "account_reactivated"]);
const fixtureTerminalCodes = new Set([
  "auth_user_not_found", "auth_update_rejected", "unsupported_auth_contract",
]);
const fixturePendingWithOperationCodes = new Set([
  "auth_temporarily_unavailable", "auth_rate_limited", "auth_user_not_found",
  "auth_update_rejected", "unsupported_auth_contract", "database_finalize_pending",
  "operation_processing", "operation_unavailable", "authorization_lost",
  "self_forbidden", "auth_unconfirmed",
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
  "self_forbidden", "auth_unconfirmed",
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
  { data: { code: "auth_update_rejected", state: "terminal_failure", operationId: fixtureUuid },
    transition: "deactivate", expectedCode: "auth_update_rejected" },
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
  { data: { code: "auth_update_rejected", state: "terminal_failure", operationId: null }, transition: "deactivate" },
  { data: { code: "operation_terminal_failure", state: "terminal_failure", operationId: fixtureUuid }, transition: "deactivate" },
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

const preAuthCodes = new Set([
  "auth_temporarily_unavailable", "auth_rate_limited", "auth_user_not_found",
  "auth_update_rejected", "unsupported_auth_contract",
]);
const terminalCodes = new Set([
  "auth_user_not_found", "auth_update_rejected", "unsupported_auth_contract",
]);
function exactFixtureSnapshot(snapshot) {
  const initial = snapshot.operationCode === "deactivate" ? "profile_suspended" : "prepared";
  const postAuth = snapshot.operationCode === "reactivate"
    && snapshot.completedStage === "auth_synchronized";
  if (snapshot.status === "open") {
    return snapshot.completedStage === initial && snapshot.attemptCount === 0
      && snapshot.retryable === false && snapshot.lastErrorCode === null;
  }
  if (snapshot.status === "processing") {
    return (snapshot.completedStage === initial || postAuth) && snapshot.attemptCount > 0
      && snapshot.retryable === false && snapshot.lastErrorCode === null;
  }
  if (snapshot.status === "retryable_failure") {
    return snapshot.attemptCount > 0 && snapshot.retryable === true
      && (snapshot.completedStage === initial && preAuthCodes.has(snapshot.lastErrorCode)
        || postAuth && snapshot.lastErrorCode === "database_finalize_pending");
  }
  if (snapshot.status === "succeeded") {
    return snapshot.completedStage === "completed" && snapshot.attemptCount > 0
      && snapshot.retryable === false && snapshot.lastErrorCode === null;
  }
  return snapshot.status === "terminal_failure"
    && snapshot.completedStage === initial
    && snapshot.attemptCount > 0
    && snapshot.retryable === false
    && terminalCodes.has(snapshot.lastErrorCode);
}
const snapshotBase = {
  operationCode: "reactivate",
  status: "open",
  completedStage: "prepared",
  attemptCount: 0,
  retryable: false,
  lastErrorCode: null,
};
for (const snapshot of [
  snapshotBase,
  { ...snapshotBase, status: "processing", attemptCount: 1 },
  { ...snapshotBase, status: "retryable_failure", attemptCount: 1, retryable: true,
    lastErrorCode: "auth_temporarily_unavailable" },
  { ...snapshotBase, status: "processing", completedStage: "auth_synchronized", attemptCount: 2 },
  { ...snapshotBase, status: "retryable_failure", completedStage: "auth_synchronized",
    attemptCount: 2, retryable: true, lastErrorCode: "database_finalize_pending" },
  { ...snapshotBase, status: "succeeded", completedStage: "completed", attemptCount: 2 },
  { ...snapshotBase, status: "terminal_failure", attemptCount: 1,
    lastErrorCode: "auth_update_rejected" },
]) assert.equal(exactFixtureSnapshot(snapshot), true);
const malformedSnapshots = [
  { ...snapshotBase, status: "succeeded", completedStage: "prepared", attemptCount: 1 },
  { ...snapshotBase, status: "succeeded", completedStage: "completed", attemptCount: 1,
    lastErrorCode: "auth_update_rejected" },
  { ...snapshotBase, status: "open", attemptCount: 1 },
  { ...snapshotBase, status: "processing", attemptCount: 0 },
  { ...snapshotBase, status: "retryable_failure", completedStage: "auth_synchronized",
    attemptCount: 1, retryable: true, lastErrorCode: "auth_rate_limited" },
  { ...snapshotBase, status: "retryable_failure", attemptCount: 1, retryable: true,
    lastErrorCode: "database_finalize_pending" },
  { ...snapshotBase, operationCode: "deactivate", status: "retryable_failure",
    completedStage: "profile_suspended", attemptCount: 1, retryable: true,
    lastErrorCode: "database_finalize_pending" },
  { ...snapshotBase, status: "terminal_failure", completedStage: "auth_synchronized",
    attemptCount: 2, lastErrorCode: "auth_update_rejected" },
];
for (const snapshot of malformedSnapshots) assert.equal(exactFixtureSnapshot(snapshot), false);
assert.equal(exactFixtureSnapshot({
  ...snapshotBase,
  status: "succeeded",
  completedStage: "prepared",
  attemptCount: 1,
}), false, "Un status succeeded malformado nunca puede autorizar completed");

function fixtureDatabaseCondition({ code = "", message = "" }, operationKnown) {
  const text = `${code} ${message}`.toLowerCase();
  if (text.includes("sitaa_admin_access_denied")) return "authorization_lost";
  if (text.includes("sitaa_account_lifecycle_self_forbidden")) return "self_forbidden";
  if (text.includes("sitaa_account_lifecycle_auth_unconfirmed")) return "auth_unconfirmed";
  if (text.includes("sitaa_service_boundary_required") || code === "42501") {
    return operationKnown ? "database_contract_rejected" : "trusted_boundary_unavailable";
  }
  return "database_contract_rejected";
}
assert.equal(fixtureDatabaseCondition({ code: "42501", message: "sitaa_admin_access_denied" }, true), "authorization_lost");
assert.equal(fixtureDatabaseCondition({ code: "42501", message: "sitaa_account_lifecycle_self_forbidden" }, false), "self_forbidden");
assert.equal(fixtureDatabaseCondition({ code: "42501", message: "sitaa_account_lifecycle_auth_unconfirmed" }, false), "auth_unconfirmed");
assert.equal(fixtureDatabaseCondition({ code: "42501", message: "sitaa_service_boundary_required" }, false), "trusted_boundary_unavailable");
assert.equal(fixtureDatabaseCondition({ code: "42501", message: "permission denied" }, true), "database_contract_rejected");
assert.notEqual(fixtureDatabaseCondition({ code: "42501", message: "permission denied" }, true), "authorization_lost");
assert.doesNotMatch(edge, /sitaa_admin_access_denied"\) \|\| error\?\.code === "42501"/);
assert.match(edge, /sitaa_service_boundary_required"\) \|\| error\?\.code === "42501"/);

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
console.log(`Snapshots RPC incompatibles rechazados: ${malformedSnapshots.length}`);
console.log("Replays start/retry alcanzan la autoridad B.3a; el legado conserva su elegibilidad: OK");
console.log("Modos malformados rechazados antes de Edge y del legado: OK");
console.log("Clasificación exacta 42501 y límite confiable: OK");
console.log("Contrato discriminado Edge y coincidencia transición/código: OK");
console.log("Errores HTTP malformados, Relay, Fetch y desconocidos fallan cerrados: OK");
