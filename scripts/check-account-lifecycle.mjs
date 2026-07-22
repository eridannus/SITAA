import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import vm from "node:vm";
import { fileURLToPath } from "node:url";
import ts from "typescript";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const helperPath = path.join(root, "lib", "admin", "account-lifecycle-permissions.ts");
const helperSource = fs.readFileSync(helperPath, "utf8");
const detailSource = fs.readFileSync(path.join(root, "app", "admin", "accounts", "[id]", "page.tsx"), "utf8");
const actionSource = fs.readFileSync(path.join(root, "app", "admin", "accounts", "[id]", "lifecycle", "actions.ts"), "utf8");
const formSource = fs.readFileSync(path.join(root, "app", "admin", "accounts", "[id]", "lifecycle", "account-lifecycle-form.tsx"), "utf8");
const dataSource = fs.readFileSync(path.join(root, "lib", "admin", "account-lifecycle.ts"), "utf8");
const identitySource = fs.readFileSync(path.join(root, "lib", "admin", "identity-correction.ts"), "utf8");
const allLifecycleSource = `${detailSource}\n${actionSource}\n${formSource}\n${dataSource}`;

const output = ts.transpileModule(helperSource, {
  compilerOptions: { module: ts.ModuleKind.CommonJS, target: ts.ScriptTarget.ES2022, strict: true },
  fileName: helperPath,
  reportDiagnostics: true,
});
if (output.diagnostics?.length) {
  throw new Error(ts.formatDiagnosticsWithColorAndContext(output.diagnostics, {
    getCanonicalFileName: (fileName) => fileName,
    getCurrentDirectory: () => root,
    getNewLine: () => "\n",
  }));
}
const compiledModule = { exports: {} };
vm.runInNewContext(output.outputText, { module: compiledModule, exports: compiledModule.exports });
const { getAdminAccountLifecyclePresentation } = compiledModule.exports;
assert.equal(typeof getAdminAccountLifecyclePresentation, "function");

function context(overrides = {}) {
  return {
    targetProfileId: "synthetic",
    accountKind: "institutional",
    accountStatus: "active",
    isSelf: false,
    canDeactivate: true,
    canReactivate: false,
    denialCode: null,
    hasExactB1Assignment: false,
    activeExactB1AdminCount: 2,
    currentOrFutureAssignmentCount: 0,
    openResponsibilityCount: 0,
    openParticipationCount: 0,
    ...overrides,
  };
}

assert.equal(getAdminAccountLifecyclePresentation(context()).action, "deactivate");
assert.equal(getAdminAccountLifecyclePresentation(context({ accountStatus: "inactive", canDeactivate: false, canReactivate: true })).action, "reactivate");
for (const target of [
  context({ accountStatus: "pending_registration", canDeactivate: false, denialCode: "pending_target" }),
  context({ isSelf: true, canDeactivate: false, denialCode: "self_forbidden" }),
  context({ hasExactB1Assignment: true, activeExactB1AdminCount: 1, canDeactivate: false, denialCode: "last_admin" }),
  context({ canDeactivate: "true" }),
  null,
]) assert.equal(getAdminAccountLifecyclePresentation(target).action, null);
assert.equal(getAdminAccountLifecyclePresentation(context({ accountKind: "technical" })).action, "deactivate");
assert.equal(getAdminAccountLifecyclePresentation(context({ accountKind: "technical", accountStatus: "inactive", canDeactivate: false, canReactivate: true })).action, "reactivate");
assert.equal(getAdminAccountLifecyclePresentation(context({ accountStatus: "inactive", canDeactivate: false, canReactivate: true, currentOrFutureAssignmentCount: 1 })).showDependencyWarning, true);
assert.equal(getAdminAccountLifecyclePresentation(context({ openResponsibilityCount: 1 })).showDependencyWarning, true);

assert.match(dataSource, /get_admin_account_lifecycle_context_b2b/);
assert.match(dataSource, /transition_admin_account_lifecycle_b2b/);
assert.match(dataSource, /migration_pending/);
assert.match(dataSource, /function parseContextRow/);
assert.match(dataSource, /function parseMutationRow/);
assert.match(actionSource, /lifecycle=\$\{/);
assert.match(detailSource, /account_deactivated:\s*"Cuenta desactivada"/);
assert.match(detailSource, /account_reactivated:\s*"Cuenta reactivada"/);
assert.doesNotMatch(allLifecycleSource, /\.from\("profiles"\)\s*\.update|auth\.admin|service[_-]?role/i);
assert.match(identitySource, /correct_admin_account_identity_b2a/);
assert.doesNotMatch(formSource, /localStorage|sessionStorage|URLSearchParams/);
assert.match(formSource, /name="transition_reason"/);
assert.match(formSource, /name="confirmation"/);

console.log("Contrato de ciclo de vida administrativo: OK");
