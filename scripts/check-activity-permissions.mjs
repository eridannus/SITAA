import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import vm from "node:vm";
import { fileURLToPath } from "node:url";
import ts from "typescript";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const helperPath = path.join(
  root,
  "lib",
  "activities",
  "activity-detail-permissions.ts",
);
const source = fs.readFileSync(helperPath, "utf8");
const activityPageSource = fs.readFileSync(
  path.join(root, "app", "activities", "[id]", "page.tsx"),
  "utf8",
);
const participantActionsSource = fs.readFileSync(
  path.join(root, "app", "activities", "[id]", "participants", "actions.ts"),
  "utf8",
);
const output = ts.transpileModule(source, {
  compilerOptions: {
    module: ts.ModuleKind.CommonJS,
    target: ts.ScriptTarget.ES2022,
    strict: true,
  },
  fileName: helperPath,
  reportDiagnostics: true,
});

if (output.diagnostics?.length) {
  const message = ts.formatDiagnosticsWithColorAndContext(output.diagnostics, {
    getCanonicalFileName: (fileName) => fileName,
    getCurrentDirectory: () => root,
    getNewLine: () => "\n",
  });
  throw new Error(message);
}

const compiledModule = { exports: {} };
vm.runInNewContext(output.outputText, {
  module: compiledModule,
  exports: compiledModule.exports,
});
const { getActivityDetailPermissions } = compiledModule.exports;

assert.equal(typeof getActivityDetailPermissions, "function");

function permissions(overrides = {}) {
  return getActivityDetailPermissions({
    isDraft: false,
    isOwnDraft: false,
    studentOnly: false,
    canEditActivity: false,
    canUpdateActivityBase: false,
    canDeleteActivity: false,
    ...overrides,
  });
}

const sameProgramResponsible = permissions({ canEditActivity: true });
assert.equal(sameProgramResponsible.canManageParticipants, true);
assert.equal(sameProgramResponsible.canManageAttendance, true);
assert.equal(sameProgramResponsible.canUpdateBaseData, false);

const historicalCrossProgramResponsible = permissions({ canEditActivity: true });
assert.equal(historicalCrossProgramResponsible.canManageParticipants, true);
assert.equal(historicalCrossProgramResponsible.canManageAttendance, true);
assert.equal(historicalCrossProgramResponsible.canUpdateBaseData, false);
assert.equal(historicalCrossProgramResponsible.canDeleteActivityRecord, false);

const crossProgramCreator = permissions({ canEditActivity: true });
assert.equal(crossProgramCreator.canManageParticipants, true);
assert.equal(crossProgramCreator.canManageAttendance, true);

const outOfScopeActor = permissions();
assert.equal(outOfScopeActor.canManageParticipants, false);
assert.equal(outOfScopeActor.canManageAttendance, false);

const baseCorrectionOnly = permissions({ canUpdateActivityBase: true });
assert.equal(baseCorrectionOnly.canManageParticipants, false);
assert.equal(baseCorrectionOnly.canUpdateBaseData, true);
assert.equal(baseCorrectionOnly.canDeleteActivityRecord, false);

const deletionOnly = permissions({ canDeleteActivity: true });
assert.equal(deletionOnly.canManageParticipants, false);
assert.equal(deletionOnly.canUpdateBaseData, false);
assert.equal(deletionOnly.canDeleteActivityRecord, true);

const ownDraft = permissions({
  isDraft: true,
  isOwnDraft: true,
  canEditActivity: true,
  canUpdateActivityBase: true,
  canDeleteActivity: true,
});
assert.equal(ownDraft.canManageParticipants, false);
assert.equal(ownDraft.canManageAttendance, false);
assert.equal(ownDraft.canUpdateBaseData, true);
assert.equal(ownDraft.canDeleteActivityRecord, true);

const studentParticipant = permissions({
  studentOnly: true,
  canEditActivity: true,
});
assert.equal(studentParticipant.canManageParticipants, false);
assert.equal(studentParticipant.canManageAttendance, false);

for (const invalidPermission of [null, undefined, "true", 1, {}]) {
  const failClosed = permissions({ canEditActivity: invalidPermission });
  assert.equal(failClosed.canManageParticipants, false);
  assert.equal(failClosed.canManageAttendance, false);
}

// El identificador y el programa actual no forman parte de esta composición.
// Por ello una corrección de cualquiera de esos datos conserva el resultado
// autoritativo entregado por can_edit_activity para creador o responsable.
const beforeIdentityCorrection = permissions({ canEditActivity: true });
const afterIdentifierCorrection = permissions({ canEditActivity: true });
const afterHistoricalProgramCorrection = permissions({ canEditActivity: true });
assert.deepEqual(afterIdentifierCorrection, beforeIdentityCorrection);
assert.deepEqual(afterHistoricalProgramCorrection, beforeIdentityCorrection);

assert.match(
  activityPageSource,
  /rpc\("can_edit_activity",\s*\{\s*target_activity_id:\s*id\s*\}\)/,
);
assert.match(
  participantActionsSource,
  /rpc\("can_edit_activity",\s*\{\s*target_activity_id:\s*activityId\s*\}\)/,
);
assert.doesNotMatch(activityPageSource, /canManageActivityScope/);
assert.doesNotMatch(participantActionsSource, /canManageActivityScope/);
assert.match(activityPageSource, /canManageAttendance\s*&&\s*<AttendanceCheckinManager/);
assert.match(activityPageSource, /canManageParticipants\s*&&\s*\(participantsError/);
assert.match(activityPageSource, /attendanceDeadlinePassed=\{attendanceDeadlinePassed\}/);
assert.match(participantActionsSource, /activity\.status_code\s*===\s*"draft"/);

console.log("Composición de permisos de actividad: OK");
