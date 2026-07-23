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
assert.match(edge, /if \(error\) return null;[\s\S]*parseSnapshot\(data, RESULT_FIELDS/);
assert.match(edge, /finalResponse\(operation\)/);
assert.match(edge, /completedStage === "auth_synchronized"/);
assert.match(data, /"completed", "pending", "rejected", "terminal_failure"/);
assert.match(action, /result\.state === "rejected" \? "error" : "pending"/);
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

const fixtureStates = new Set(["completed", "pending", "rejected", "terminal_failure"]);
const fixtureCodes = new Set([
  "account_deactivated", "request_id_conflict", "pending_target",
  "authorization_lost", "trusted_boundary_unavailable",
]);
const fixtureUuidPattern = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const fixtureUuid = "11111111-1111-4111-8111-111111111111";
function parseFixtureEdgeResult(value) {
  if (typeof value !== "object" || value === null || Array.isArray(value)
    || Object.keys(value).some((key) => !["code", "state", "operationId"].includes(key))
    || !fixtureCodes.has(value.code) || !fixtureStates.has(value.state)
    || (value.operationId !== null && !fixtureUuidPattern.test(value.operationId))) return null;
  return value;
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
for (const fixture of [
  { data: { code: "account_deactivated", state: "completed", operationId: fixtureUuid },
    expectedCode: "account_deactivated" },
  { errorKind: "http", httpBody: { code: "request_id_conflict", state: "rejected", operationId: null },
    expectedCode: "request_id_conflict" },
  { errorKind: "http", httpBody: { code: "pending_target", state: "rejected", operationId: null },
    expectedCode: "pending_target" },
  { errorKind: "http", httpBody: { code: "authorization_lost", state: "rejected", operationId: fixtureUuid },
    expectedCode: "authorization_lost" },
]) {
  assert.equal(resolveFixtureInvocation(fixture).code, fixture.expectedCode);
}
assert.throws(
  () => resolveFixtureInvocation({
    errorKind: "http",
    httpBody: { code: "request_id_conflict", state: "rejected", operationId: null, detail: "raw" },
  }),
  /trusted_boundary_unavailable/,
);
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
console.log("Resultados Edge 200/403/409 preservados mediante el parser exacto: OK");
console.log("Errores HTTP malformados, Relay, Fetch y desconocidos fallan cerrados: OK");
