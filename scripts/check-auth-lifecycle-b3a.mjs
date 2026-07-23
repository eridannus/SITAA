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

for (const value of ["open", "processing", "retryable_failure", "succeeded", "terminal_failure",
  "prepared", "profile_suspended", "auth_synchronized", "completed"]) assert.ok(migration.includes(`'${value}'`));
for (const rpc of ["get_admin_account_auth_lifecycle_context_b3a", "prepare_admin_account_auth_lifecycle_b3a",
  "finalize_admin_account_auth_reactivation_b3a", "claim_admin_auth_operation_b3a",
  "record_admin_auth_operation_result_b3a"]) assert.ok(migration.includes(rpc));
assert.match(migration, /admin_auth_operations_one_nonfinal_target_uidx/);
assert.match(migration, /revoke all on function public\.transition_admin_account_lifecycle_b2b[\s\S]*from public,anon,authenticated,service_role/);
assert.doesNotMatch(`${edge}\n${adapter}\n${action}\n${data}`, /immediate access-token invalidation|global sign-out|revoca(?:r|ción) criptográficamente/i);

console.log("Límite confiable Auth B.3a: OK");

