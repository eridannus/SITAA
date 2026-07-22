import assert from "node:assert/strict";
import crypto from "node:crypto";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const paths = {
  migration: "supabase/migrations/0009_admin_account_lifecycle_transitions.sql",
  preflight: "supabase/reconciliation/0009_admin_account_lifecycle_transitions_preflight.sql",
  verify: "supabase/reconciliation/0009_admin_account_lifecycle_transitions_verify.sql",
  rollback: "supabase/reconciliation/0009_admin_account_lifecycle_transitions_rollback.sql",
};
const sql = Object.fromEntries(Object.entries(paths).map(([key, value]) => [
  key,
  fs.readFileSync(path.join(root, value), "utf8"),
]));

function assertLexicallyBalanced(source, label) {
  const dollarTags = [...source.matchAll(/\$[A-Za-z_][A-Za-z0-9_]*\$|\$\$/g)].map((match) => match[0]);
  const counts = new Map();
  for (const tag of dollarTags) counts.set(tag, (counts.get(tag) ?? 0) + 1);
  for (const [tag, count] of counts) {
    assert.equal(count % 2, 0, `${label}: delimitador impar ${tag}`);
  }

  let depth = 0;
  let single = false;
  let lineComment = false;
  let blockComment = false;
  let dollar = null;
  for (let index = 0; index < source.length; index += 1) {
    const current = source[index];
    const next = source[index + 1];
    if (lineComment) {
      if (current === "\n") lineComment = false;
      continue;
    }
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
  }
  assert.equal(depth, 0, `${label}: paréntesis sin cerrar`);
  assert.equal(single, false, `${label}: literal sin cerrar`);
  assert.equal(blockComment, false, `${label}: comentario sin cerrar`);
  assert.equal(dollar, null, `${label}: cuerpo dollar-quoted sin cerrar`);
}

for (const [label, source] of Object.entries(sql)) assertLexicallyBalanced(source, label);
assert.match(sql.migration.trim(), /^--[\s\S]*\bbegin;[\s\S]*commit;$/i);
assert.match(sql.preflight.trim(), /begin transaction read only;[\s\S]*rollback;$/i);
assert.match(sql.verify.trim(), /\bbegin;[\s\S]*rollback;$/i);
assert.match(sql.rollback.trim(), /\bbegin;[\s\S]*commit;$/i);

assert.equal((sql.migration.match(/create function public\./gi) ?? []).length, 3);
assert.doesNotMatch(sql.migration, /\b(create|alter|drop)\s+(table|policy|index|trigger|type|extension)\b/i);
assert.doesNotMatch(sql.preflight, /^\s*(insert|update|delete|truncate|alter|drop|grant|revoke|create)\b/im);
assert.doesNotMatch(sql.rollback, /\bcascade\b/i);
assert.equal((sql.rollback.match(/drop function public\./gi) ?? []).length, 3);
assert.match(sql.migration, /pg_advisory_xact_lock\(1397310529,9002\)/);
assert.match(sql.migration, /lock table public\.role_assignments in share mode/i);
assert.match(sql.migration, /order by profile\.id\s+for update/i);
assert.match(sql.migration, /jsonb_build_object\('changed_fields',to_jsonb\(changed\)\)/);
assert.match(
  sql.migration,
  /sitaa_account_lifecycle_last_admin_forbidden[\s\S]*?errcode='55000'/i,
);
assert.doesNotMatch(
  Object.values(sql).join("\n"),
  /handle_sitaa_auth_user_email_changed/i,
);
for (const [label, source] of Object.entries(sql)) {
  assert.match(
    source,
    /sync_sitaa_profile_email_from_auth/i,
    `${label}: falta el handler canónico de sincronización de correo`,
  );
  assert.match(source, /on_sitaa_auth_user_created/);
  assert.match(source, /on_sitaa_auth_user_email_changed/);
  assert.doesNotMatch(source, /pg_get_expr\s*\([^)]*tgqual/i);
  for (const column of ["first_names", "paternal_surname", "maternal_surname"]) {
    assert.match(source, new RegExp(column));
  }
}
assert.doesNotMatch(sql.preflight, /where\s+aggregate_count\s*<>\s*0/i);
assert.equal(
  (sql.preflight.match(/^  \('[a-z][a-z0-9_]*',?/gm) ?? []).length,
  26,
  "El preflight debe declarar 19 categorías bloqueantes y 7 informativas",
);
assert.match(sql.preflight, /order by classification,category;/i);
assert.match(sql.verify, /\$owner_helper_contract\$/);
assert.match(sql.verify, /0009_verify_expected_helper_acl_denial/);
assert.match(sql.verify, /missing_target_context_cardinality/);
assert.match(sql.verify, /deactivation_timestamp_contract/);
assert.match(sql.verify, /reactivation_timestamp_contract/);
assert.match(sql.verify, /deactivation_audit_contract/);
assert.match(sql.verify, /reactivation_audit_contract/);
assert.match(sql.verify, /\$two_admin_safety_contract\$/);
assert.match(sql.verify, /sitaa_admin_access_denied/);
assert.match(sql.verify, /sitaa_account_lifecycle_self_forbidden/);
assert.match(
  sql.verify,
  /grant select on table pg_temp\.sitaa_0009_context to authenticated;/i,
);
assert.match(
  sql.migration,
  /account_status='inactive' and target_profile\.is_active=false\s+and target_profile\.activated_at is not null and target_profile\.deactivated_at is not null/i,
);

const expectedHashes = {
  is_exact_b1_account_admin_profile_b2b: "104d16a531ea53a5b4908102322097dc",
  get_admin_account_lifecycle_context_b2b: "6e7c8bb5e2dcf99fce6a75e03e07c309",
  transition_admin_account_lifecycle_b2b: "0080f41a2cd78576763ebb5d5128996e",
};
assert.match(
  sql.migration,
  /create function public\.is_exact_b1_account_admin_profile_b2b\(\s*requested_profile_id uuid\s*\)/i,
);
for (const [name, expectedHash] of Object.entries(expectedHashes)) {
  const match = sql.migration.match(new RegExp(
    `create function public\\.${name}\\([\\s\\S]*?as \\$function\\$\\n([\\s\\S]*?)\\n\\$function\\$;`,
    "i",
  ));
  assert.ok(match, `No se encontró el cuerpo ${name}`);
  const hash = crypto.createHash("md5").update(match[1].replace(/\s+/g, ""), "utf8").digest("hex");
  assert.equal(hash, expectedHash, `Hash normalizado inesperado para ${name}`);
  assert.match(sql.migration, new RegExp(expectedHash));
  assert.match(sql.verify, new RegExp(expectedHash));
  assert.match(sql.rollback, new RegExp(expectedHash));
  if (name === "transition_admin_account_lifecycle_b2b") {
    assert.doesNotMatch(match[1], /\b(update|insert|delete)\s+(?:from\s+|into\s+)?public\.role_assignments\b/i);
    assert.doesNotMatch(match[1], /auth\.admin/i);
  }
}

for (const source of Object.values(sql)) {
  assert.doesNotMatch(source, /postgres(?:ql)?:\/\/|supabase_db_url|service_role_key/i);
}

console.log("Contrato SQL estático de 0009: OK");
