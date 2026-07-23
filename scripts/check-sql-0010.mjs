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

function dollarQuoteTags(source) {
  const counts = new Map();
  for (const match of source.matchAll(/\$[A-Za-z_][A-Za-z0-9_]*\$|\$\$/g)) counts.set(match[0], (counts.get(match[0]) ?? 0) + 1);
  return counts;
}
for (const [name, source] of Object.entries(sources)) {
  for (const [tag, count] of dollarQuoteTags(source)) assert.equal(count % 2, 0, `${name}: delimitador ${tag} desbalanceado`);
  assert.doesNotMatch(source, /\bCASCADE\b/i, `${name}: CASCADE no permitido`);
}
assert.match(sources.migration, /^--[\s\S]*\nbegin;/);
assert.match(sources.migration.trimEnd(), /commit;$/);
assert.match(sources.preflight, /begin transaction read only;/);
assert.match(sources.preflight.trimEnd(), /rollback;$/);
assert.match(sources.verify, /^--[\s\S]*\nbegin;/);
assert.match(sources.verify.trimEnd(), /rollback;$/);
assert.match(sources.rollback.trimEnd(), /commit;$/);
assert.match(sources.rollback, /lock table public\.admin_auth_operations in access exclusive mode nowait/);
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
assert.match(sources.migration, /operation_code='reactivate' and completed_stage='auth_synchronized'/,
  "Reactivación debe poder persistir Auth sincronizado antes del evento de perfil");

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
  "0010_verify_concurrent_claim_unexpected",
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
