import assert from "node:assert/strict";
import crypto from "node:crypto";
import fs from "node:fs";
import path from "node:path";

const root = process.cwd();
const artifacts = {
  migration: "supabase/migrations/0010_coordinated_auth_session_suspension.sql",
  preflight: "supabase/reconciliation/0010_coordinated_auth_session_suspension_preflight.sql",
  verify: "supabase/reconciliation/0010_coordinated_auth_session_suspension_verify.sql",
  rollback: "supabase/reconciliation/0010_coordinated_auth_session_suspension_rollback.sql",
};
const sources = Object.fromEntries(Object.entries(artifacts).map(([key, relative]) => [key, fs.readFileSync(path.join(root, relative), "utf8")]));
const edge = fs.readFileSync(path.join(root, "supabase/functions/admin-account-auth-lifecycle/index.ts"), "utf8");
const adapter = fs.readFileSync(path.join(root, "supabase/functions/admin-account-auth-lifecycle/auth-admin-adapter.ts"), "utf8");

function lineAtOffset(source, offset) {
  return source.slice(0, offset).split("\n").length;
}

function extractDollarQuotedBodies(source, label) {
  const bodies = [];
  let single = false;
  let lineComment = false;
  let blockComment = false;
  for (let index = 0; index < source.length; index += 1) {
    const current = source[index];
    const next = source[index + 1];
    if (lineComment) { if (current === "\n") lineComment = false; continue; }
    if (blockComment) {
      if (current === "*" && next === "/") { blockComment = false; index += 1; }
      continue;
    }
    if (single) {
      if (current === "'" && next === "'") { index += 1; continue; }
      if (current === "'") single = false;
      continue;
    }
    if (current === "-" && next === "-") { lineComment = true; index += 1; continue; }
    if (current === "/" && next === "*") { blockComment = true; index += 1; continue; }
    if (current === "'") { single = true; continue; }
    if (current !== "$") continue;
    const match = source.slice(index).match(/^(\$[A-Za-z_][A-Za-z0-9_]*\$|\$\$)/);
    if (!match) continue;
    const delimiter = match[1];
    const openingOffset = index;
    const bodyOffset = openingOffset + delimiter.length;
    const closingOffset = source.indexOf(delimiter, bodyOffset);
    assert.notEqual(closingOffset, -1,
      `${label}: delimitador ${delimiter} abierto en línea ${lineAtOffset(source, openingOffset)} sin cierre`);
    bodies.push({ delimiter, body: source.slice(bodyOffset, closingOffset), openingOffset,
      closingOffset, openingLine: lineAtOffset(source, openingOffset),
      closingLine: lineAtOffset(source, closingOffset) });
    index = closingOffset + delimiter.length - 1;
  }
  return bodies;
}

function assertLexicallyBalanced(source, label) {
  extractDollarQuotedBodies(source, label);
  let depth = 0;
  let squareDepth = 0;
  let single = false;
  let lineComment = false;
  let blockComment = false;
  let dollar = null;
  for (let index = 0; index < source.length; index += 1) {
    const current = source[index];
    const next = source[index + 1];
    if (lineComment) { if (current === "\n") lineComment = false; continue; }
    if (blockComment) {
      if (current === "*" && next === "/") { blockComment = false; index += 1; }
      continue;
    }
    if (dollar) {
      if (source.startsWith(dollar, index)) { index += dollar.length - 1; dollar = null; }
      continue;
    }
    if (single) {
      if (current === "'" && next === "'") { index += 1; continue; }
      if (current === "'") single = false;
      continue;
    }
    if (current === "-" && next === "-") { lineComment = true; index += 1; continue; }
    if (current === "/" && next === "*") { blockComment = true; index += 1; continue; }
    if (current === "'") { single = true; continue; }
    if (current === "$") {
      const match = source.slice(index).match(/^(\$[A-Za-z_][A-Za-z0-9_]*\$|\$\$)/);
      if (match) { dollar = match[1]; index += dollar.length - 1; continue; }
    }
    if (current === "(") depth += 1;
    if (current === ")") depth -= 1;
    assert.ok(depth >= 0, `${label}: paréntesis de cierre inesperado`);
    if (current === "[") squareDepth += 1;
    if (current === "]") squareDepth -= 1;
    assert.ok(squareDepth >= 0, `${label}: corchete de cierre inesperado`);
  }
  assert.equal(depth, 0, `${label}: paréntesis sin cerrar`);
  assert.equal(squareDepth, 0, `${label}: corchete sin cerrar`);
  assert.equal(single, false, `${label}: literal sin cerrar`);
  assert.equal(blockComment, false, `${label}: comentario sin cerrar`);
  assert.equal(dollar, null, `${label}: cuerpo dollar-quoted sin cerrar`);
}

for (const [name, source] of Object.entries(sources)) {
  assertLexicallyBalanced(source, name);
  for (const body of extractDollarQuotedBodies(source, name)) {
    assertLexicallyBalanced(body.body, `${name}:${body.delimiter} líneas ${body.openingLine}-${body.closingLine}`);
  }
  assert.doesNotMatch(source, /\bCASCADE\b/i, `${name}: CASCADE no permitido`);
}

const brokenDollarRegression = `do $preflight$
begin
  perform exists (select 1 where (true or exists (select 1));
end;
$preflight$;`;
const brokenRegressionBody = extractDollarQuotedBodies(brokenDollarRegression, "regresión negativa")[0];
assert.throws(() => assertLexicallyBalanced(brokenRegressionBody.body, "regresión negativa:$preflight$"), /paréntesis sin cerrar/);
const correctedDollarRegression = `do $preflight$
begin
  perform exists (select 1 where (true or exists (select 1)));
end;
$preflight$;`;
const correctedRegressionBody = extractDollarQuotedBodies(correctedDollarRegression, "regresión positiva")[0];
assert.doesNotThrow(() => assertLexicallyBalanced(correctedRegressionBody.body, "regresión positiva:$preflight$"));
assert.match(sources.migration, /^--[\s\S]*\nbegin;/);
assert.match(sources.migration.trimEnd(), /commit;$/);
assert.match(sources.preflight, /begin transaction read only;/);
assert.match(sources.preflight.trimEnd(), /rollback;$/);
assert.match(sources.verify, /^--[\s\S]*\nbegin;/);
assert.match(sources.verify.trimEnd(), /rollback;$/);
assert.match(sources.rollback.trimEnd(), /commit;$/);
assert.match(sources.rollback, /lock table public\.admin_auth_operations in access exclusive mode nowait/);
assert.match(sources.rollback, /lock table public\.admin_audit_events in access exclusive mode nowait/);
assert.ok(
  sources.rollback.indexOf("lock table public.admin_auth_operations")
    < sources.rollback.indexOf("do $predestructive$"),
  "Rollback debe bloquear ledger antes de la guarda completa",
);
assert.ok(
  sources.rollback.indexOf("lock table public.admin_audit_events")
    < sources.rollback.indexOf("do $predestructive$"),
  "Rollback debe bloquear auditoría antes de la guarda completa",
);
assert.match(sources.rollback, /if exists\(select 1 from public\.admin_auth_operations\)/);
assert.match(sources.rollback, /grant execute on function public\.transition_admin_account_lifecycle_b2b/);
assert.match(sources.rollback, /revoke all on function public\.guard_admin_auth_operation_b3a\(\)/);
assert.match(sources.rollback, /sitaa_0010_rollback_exact_contract_mismatch/);
assert.match(sources.rollback, /with expected\(function_oid,grantee\)/);
assert.match(sources.migration, /with expected\(function_oid,grantee\)/, "La guarda 0010 debe comparar ACL exacta");
assert.match(sources.verify, /with expected\(function_oid,grantee\)/, "El verificador debe comparar ACL exacta");
assert.match(sources.migration, /sitaa_0010_post_ddl_function_body_mismatch/);
assert.match(sources.verify, /0010_verify_function_body_mismatch/);
assert.match(sources.migration, /public\.guard_admin_auth_operation_b3a\(\)'::regprocedure::oid,'postgres'::regrole::oid/);
assert.match(sources.verify, /public\.guard_admin_auth_operation_b3a\(\)'::regprocedure::oid,'postgres'::regrole::oid/);
assert.doesNotMatch(`${sources.migration}\n${sources.verify}`, /has_function_privilege\('PUBLIC'/i);
assert.match(sources.migration, /id:uuid:NO\|request_id:uuid:NO[\s\S]*updated_at:timestamp with time zone:NO/);
assert.match(sources.migration, /operation_code='reactivate'[\s\S]{0,240}completed_stage in \('prepared','auth_synchronized','completed'\)/,
  "Reactivación debe poder persistir Auth sincronizado antes del evento de perfil");
assert.match(sources.migration, /writer is null or writer not in \('prepare','claim','record','finalize'\)/,
  "El writer guard debe rechazar NULL explícitamente");
assert.ok((sources.migration.match(/set_config\('sitaa\.b3a_writer','',true\)/g) ?? []).length >= 4,
  "Cada ruta DML aprobada debe limpiar el writer");
const prepareStart = sources.migration.indexOf("create function public.prepare_admin_account_auth_lifecycle_b3a");
const prepareEnd = sources.migration.indexOf("$function$;", sources.migration.indexOf("as $function$", prepareStart));
const prepareBody = sources.migration.slice(prepareStart, prepareEnd);
assert.ok(prepareBody.indexOf("pg_advisory_xact_lock") < prepareBody.indexOf("operation.request_id=$4 for update"),
  "El lock de ciclo debe preceder la consulta autoritativa request_id");
assert.match(sources.migration, /requested_result is null or requested_result not in/);
assert.match(sources.migration, /stable_error_code is null[\s\S]*retryable_failure/);
assert.doesNotMatch(sources.migration, /operation\.status<>'succeeded'[\s\S]{0,160}order by operation\.requested_at/,
  "El contexto debe seleccionar la operación más reciente antes de derivar su estado");
assert.match(sources.migration, /defaclobjtype::text/);
assert.match(sources.migration, /aclexplode\(table_definition\.relacl\)[\s\S]*=8/);

for (const expected of sources.verify.matchAll(/sqlerrm<>'(sitaa_[^']+)'/g)) {
  assert.ok(sources.migration.includes(`'${expected[1]}'`),
    `Error estable del verificador ausente en implementación: ${expected[1]}`);
}
assert.equal((edge.match(/\.rpc\("record_admin_auth_operation_result_b3a"/g) ?? []).length, 1,
  "Toda persistencia de resultado debe pasar por el helper validado único");
assert.match(edge, /const \{ data, error \} = await client\.rpc\("record_admin_auth_operation_result_b3a"/);
assert.match(edge, /if \(error\) return null;[\s\S]*parseSnapshot\(data, RESULT_FIELDS/);
assert.doesNotMatch(adapter, /result:\s*"terminal_failure"/,
  "El adaptador provisional no puede emitir fallos terminales");
for (const retryableCode of ["auth_temporarily_unavailable", "auth_rate_limited", "auth_user_not_found",
  "auth_update_rejected", "unsupported_auth_contract", "database_finalize_pending"]) {
  assert.match(sources.migration,
    new RegExp(`requested_result='retryable_failure'[\\s\\S]{0,600}'${retryableCode}'`),
    `El contrato SQL reintentable no acepta ${retryableCode}`);
}

for (const required of ["admin_auth_operations", "request_id", "requested_by_profile_id", "completed_by_profile_id",
  "target_profile_id", "operation_code", "status", "completed_stage", "attempt_count", "last_error_code",
  "profile_audit_event_id", "auth_audit_event_id", "processing_started_at", "auth_synchronized_at", "completed_at"]) {
  assert.ok(sources.migration.includes(required), `Falta contrato SQL: ${required}`);
}
for (const code of ["account_auth_suspended", "account_auth_restored", "account_auth_suspension_failed", "account_auth_restoration_failed"]) {
  assert.ok(sources.migration.includes(code), `Falta acción auditada: ${code}`);
}
for (const status of ["open", "processing", "retryable_failure", "succeeded", "terminal_failure"]) {
  assert.ok(sources.migration.includes(`'${status}'`), `Falta estado 0010: ${status}`);
}
for (const stage of ["prepared", "profile_suspended", "auth_synchronized", "completed"]) {
  assert.ok(sources.migration.includes(`'${stage}'`), `Falta etapa 0010: ${stage}`);
}

const functionSignatures = [
  ["guard_admin_auth_operation_b3a", "guard_admin_auth_operation_b3a()"],
  ["get_admin_account_auth_lifecycle_context_b3a", "get_admin_account_auth_lifecycle_context_b3a(uuid)"],
  ["prepare_admin_account_auth_lifecycle_b3a", "prepare_admin_account_auth_lifecycle_b3a(uuid,text,text,uuid)"],
  ["claim_admin_auth_operation_b3a", "claim_admin_auth_operation_b3a(uuid,uuid)"],
  ["record_admin_auth_operation_result_b3a", "record_admin_auth_operation_result_b3a(uuid,uuid,text,text)"],
  ["finalize_admin_account_auth_reactivation_b3a", "finalize_admin_account_auth_reactivation_b3a(uuid)"],
];
for (const [name, signature] of functionSignatures) {
  const start = sources.migration.indexOf(`create function public.${name}`);
  const bodyStart = sources.migration.indexOf("as $function$", start) + "as $function$".length;
  const bodyEnd = sources.migration.indexOf("$function$;", bodyStart);
  assert.ok(start >= 0 && bodyStart >= "as $function$".length && bodyEnd > bodyStart, `No se pudo extraer ${signature}`);
  const bodyHash = crypto.createHash("md5")
    .update(sources.migration.slice(bodyStart, bodyEnd).replace(/\s+/g, ""))
    .digest("hex");
  const expectedPair = `('${signature}','${bodyHash}')`;
  assert.ok(sources.migration.includes(expectedPair), `Hash post-DDL desactualizado: ${signature}`);
  assert.ok(sources.verify.includes(expectedPair), `Hash de verificador desactualizado: ${signature}`);
  assert.ok(sources.rollback.includes(expectedPair), `Hash de rollback desactualizado: ${signature}`);
}
assert.match(sources.verify, /@example\.invalid/);
assert.match(sources.verify, /set local role authenticated/);
assert.match(sources.verify, /set local role service_role/);
assert.match(sources.verify, /rollback;/);
assert.doesNotMatch(sources.verify, /auth\.admin|updateUserById|SUPABASE_SERVICE_ROLE_KEY/);
for (const marker of [
  "0010_verify_malformed_admin_unexpected",
  "0010_verify_inactive_admin_unexpected",
  "0010_verify_context_cardinality_failed",
  "0010_verify_second_open_operation_unexpected",
  "0010_verify_fresh_processing_contract_failed",
  "0010_verify_missing_writer_insert_unexpected",
  "0010_verify_missing_writer_update_unexpected",
  "0010_verify_empty_writer_unexpected",
  "0010_verify_unknown_writer_unexpected",
  "0010_verify_writer_not_cleared",
  "0010_verify_null_result_unexpected",
  "0010_verify_null_retryable_code_unexpected",
  "0010_verify_null_terminal_code_unexpected",
  "0010_verify_success_error_code_unexpected",
  "0010_verify_auth_synchronized_immediate_recovery_failed",
  "0010_verify_final_operation_replay_failed",
  "0010_verify_latest_success_selection_failed",
  "0010_verify_terminal_result_failed",
  "0010_verify_failed_finalization_activated_profile",
  "0010_verify_retry_repeated_auth_stage",
  "0010_verify_lost_authority_activated_profile",
  "0010_verify_preexisting_operational_history_changed",
  "0010_verify_delete_unexpected",
  "0010_verify_truncate_unexpected",
]) assert.ok(sources.verify.includes(marker), `Falta caso verificador: ${marker}`);

const immutable = new Map([
  ["0001_baseline_current_schema.sql", "62c8e53d794716b22cef2bd1008aa6704f8541cfc660825d4d8a538891274dfd"],
  ["0002_database_security_and_integrity.sql", "59a8bb986d84f58b4f13a9d990bf1dee59e06877fa635d95acf90538fd1ff949"],
  ["0003_fix_draft_temporal_lifecycle.sql", "059f0ee574015fc8f5a01631a7d6f894ffd429cfb3f790c9c858cd4cbe4d61e3"],
  ["0004_identity_registration_foundation.sql", "1a0ee8a54ecaa627c25b116189113ac84ef07b2f0f4ac60731dd64143cd0c6f5"],
  ["0005_fix_google_oauth_user_creation.sql", "89a7f8a9dce2df9e0466101c254a80a05493b93d7796bf772e6b46d7004663b5"],
  ["0006_structured_person_names.sql", "330dbd4d5a5fc5d508100ca09a3f4c989bd0e7a4ce4aadff2daaf4ab352db1f3"],
  ["0007_admin_account_directory_audit.sql", "967dccf8acabdd0955947cf42b97727e73072e1d5c7b0a8a2f574e126fce32d4"],
  ["0008_operational_account_barrier_identity_correction.sql", "9e5f05ef02f81e62a31e19ad4c7a693f323c0a4936cbf816fd3757295fb11c17"],
  ["0009_admin_account_lifecycle_transitions.sql", "c525998b028d5d0f8f7eed6803444b4a8e529e478c7846e8894227a65593b922"],
]);
for (const [file, expected] of immutable) {
  const digest = crypto.createHash("sha256").update(fs.readFileSync(path.join(root, "supabase/migrations", file))).digest("hex");
  assert.equal(digest, expected, `Migración inmutable modificada: ${file}`);
}
assert.equal(fs.readdirSync(path.join(root, "supabase/migrations")).some((name) => /^0011_/.test(name)), false);
console.log("Contrato SQL estático de 0010: OK");
