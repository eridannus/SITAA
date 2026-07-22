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

for (const [label, source] of Object.entries(sql)) {
  const beginPattern = label === "preflight"
    ? /begin transaction read only;\s*set local time zone 'UTC';\s*set local datestyle to 'ISO, MDY';/i
    : /\bbegin;\s*set local time zone 'UTC';\s*set local datestyle to 'ISO, MDY';/i;
  assert.match(source, beginPattern, `${label}: falta el bloque canónico inmediatamente después de BEGIN`);
  assert.equal((source.match(/set local time zone 'UTC';/gi) ?? []).length, 1, `${label}: TimeZone debe fijarse una vez`);
  assert.equal((source.match(/set local datestyle to 'ISO, MDY';/gi) ?? []).length, 1, `${label}: DateStyle debe fijarse una vez`);
  const beginAt = label === "preflight"
    ? source.search(/begin transaction read only;/i)
    : source.search(/\bbegin;/i);
  const timeZoneAt = source.search(/set local time zone 'UTC';/i);
  const dateStyleAt = source.search(/set local datestyle to 'ISO, MDY';/i);
  const firstSeedHashAt = source.search(/2e450238768fbe9889470864a1832486/i);
  assert.ok(beginAt >= 0 && beginAt < timeZoneAt && timeZoneAt < dateStyleAt && dateStyleAt < firstSeedHashAt,
    `${label}: orden inválido de transacción, sesión canónica y hash de semillas`);
  assert.doesNotMatch(source, /alter\s+(?:database|role)\b[\s\S]{0,160}\bset\s+(?:time\s+zone|timezone|datestyle)\b/i);
  assert.doesNotMatch(source, /alter\s+system\b/i);
}

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
assert.match(sql.verify, /\$two_admin_owner_baseline\$/);
assert.match(sql.verify, /\$two_admin_deactivate_client\$/);
assert.match(sql.verify, /\$two_admin_deactivate_owner\$/);
assert.match(sql.verify, /\$two_admin_reciprocal_client\$/);
assert.match(sql.verify, /\$two_admin_restore_owner\$/);
assert.match(sql.verify, /sitaa_admin_access_denied/);
assert.match(sql.verify, /sitaa_account_lifecycle_self_forbidden/);
assert.match(sql.verify, /sitaa_0009_baseline_exact_admins/);
assert.match(sql.verify, /sitaa_0009_baseline_counts/);
assert.match(sql.verify, /baseline_count\+2/);
assert.match(sql.verify, /baseline_count\+1/);
assert.match(sql.verify, /sitaa_0009_allocated_identifiers/);
assert.match(sql.verify, /create function pg_temp\.allocate_identifier\(target_label text\)/i);
assert.match(sql.verify, /target_identifier\s+text:=case[\s\S]*?pg_temp\.allocate_identifier\(target_label\)/i);
assert.doesNotMatch(sql.verify, /target_identifier:=.*md5/i);
assert.match(sql.verify, /0009_verify_live_exact_admin_baseline_changed/);
assert.doesNotMatch(sql.preflight, /activity_has_ended\s*\(/i);
assert.match(
  sql.verify,
  /grant select on table pg_temp\.sitaa_0009_context to authenticated;/i,
);
assert.match(sql.verify, /grant select on table pg_temp\.sitaa_0009_cases to authenticated;/i);
assert.match(sql.verify, /grant select,insert on table pg_temp\.sitaa_0009_results to authenticated;/i);
assert.match(sql.verify, /grant select on table pg_temp\.sitaa_0009_baseline_counts to authenticated;/i);
assert.match(sql.verify, /grant execute on function pg_temp\.case_id\(text\),pg_temp\.set_request_user\(text\) to authenticated;/i);
assert.doesNotMatch(sql.verify, /active_exact_b1_admin_count\s*(?:=|<>)\s*2\b/i);
assert.doesNotMatch(sql.verify, /observed_count\s*<>\s*[12]\b/i);
assert.match(
  sql.migration,
  /account_status='inactive' and target_profile\.is_active=false\s+and target_profile\.activated_at is not null and target_profile\.deactivated_at is not null/i,
);

const postDdl = sql.migration.match(/do \$post_ddl\$([\s\S]*?)\$post_ddl\$;/i)?.[1];
assert.ok(postDdl, "No se encontró la guarda post-DDL de 0009");
assert.match(postDdl, /pg_get_userbyid\(p\.proowner\)='postgres'/i);
assert.match(postDdl, /\bor acl\.is_grantable\b/i);
assert.doesNotMatch(postDdl, /acl\.is_grantable\s+and\s+acl\.grantee/i);
assert.match(postDdl, /is_exact_b1_account_admin_profile_b2b\(uuid\)'::regprocedure\)<>1/i);
assert.match(postDdl, /get_admin_account_lifecycle_context_b2b\(uuid\)'::regprocedure\)<>2/i);
assert.match(postDdl, /transition_admin_account_lifecycle_b2b\(uuid,text,text\)'::regprocedure\)<>2/i);

assert.match(sql.verify, /where p\.oid=helper_oid\)<>1/i);
assert.match(sql.verify, /where p\.oid=context_oid\)<>2/i);
assert.match(sql.verify, /where p\.oid=mutation_oid\)<>2/i);
assert.match(sql.rollback, /is_exact_b1_account_admin_profile_b2b\(uuid\)'::regprocedure\)<>1/i);
assert.match(sql.rollback, /get_admin_account_lifecycle_context_b2b\(uuid\)'::regprocedure\)<>2/i);
assert.match(sql.rollback, /transition_admin_account_lifecycle_b2b\(uuid,text,text\)'::regprocedure\)<>2/i);

const expectedHashes = {
  is_exact_b1_account_admin_profile_b2b: "104d16a531ea53a5b4908102322097dc",
  get_admin_account_lifecycle_context_b2b: "6e7c8bb5e2dcf99fce6a75e03e07c309",
  transition_admin_account_lifecycle_b2b: "7f940968051ff1b844443f6c76b561c3",
};
for (const source of [sql.migration, sql.verify, sql.rollback]) {
  assert.match(source, /71f9763d702e95e4eede51a4a4611694/);
}

function authenticatedIntervals(source) {
  const boundary = /\b(set local role authenticated|reset role)\s*;/gi;
  const intervals = [];
  let active = null;
  let match;
  while ((match = boundary.exec(source)) !== null) {
    const command = match[1].toLowerCase();
    if (command.startsWith("set local")) {
      assert.equal(active, null, "Intervalo authenticated anidado en el verificador");
      active = boundary.lastIndex;
    } else {
      assert.notEqual(active, null, "RESET ROLE sin SET LOCAL ROLE authenticated");
      intervals.push(source.slice(active, match.index));
      active = null;
    }
  }
  assert.equal(active, null, "Falta RESET ROLE para un intervalo authenticated");
  return intervals;
}

const clientIntervals = authenticatedIntervals(sql.verify);
assert.ok(clientIntervals.length >= 10, "El verificador perdió sus fases cliente authenticated");
let protectedHelperCalls = 0;
let directDenialIntervals = 0;
for (const interval of clientIntervals) {
  assert.doesNotMatch(
    interval,
    /\b(?:from|join)\s+(?:public\.(?:profiles|role_assignments|activities|activity_participants|admin_audit_events)|auth\.(?:users|identities))\b/i,
    "Una fase cliente authenticated contiene una lectura cruda protegida",
  );
  assert.doesNotMatch(
    interval,
    /public\.is_b1_account_admin\s*\(/i,
    "Una fase cliente authenticated invoca directamente el helper histórico B.1",
  );
  protectedHelperCalls += (interval.match(/public\.is_exact_b1_account_admin_profile_b2b\s*\(/gi) ?? []).length;

  const directWrites = interval.match(
    /\b(?:update\s+public\.(?:profiles|role_assignments|admin_audit_events)|insert\s+into\s+(?:public\.(?:profiles|role_assignments|admin_audit_events)|auth\.(?:users|identities))|delete\s+from\s+(?:public\.(?:profiles|role_assignments|admin_audit_events)|auth\.(?:users|identities)))/gi,
  ) ?? [];
  if (directWrites.length > 0) {
    directDenialIntervals += 1;
    assert.match(interval, /\$direct_acl_denial_contract\$/);
    assert.equal(directWrites.length, 2, "La prueba ACL directa debe contener sólo dos escrituras negativas");
    assert.match(interval, /exception when insufficient_privilege then null;/i);
  }
}
assert.equal(protectedHelperCalls, 1, "Debe existir una sola invocación cliente del helper privado");
assert.equal(directDenialIntervals, 1, "Debe existir un solo intervalo de escrituras directas negativas");
assert.match(sql.verify, /\$private_helper_acl_denial\$[\s\S]*?sqlstate '42501'[\s\S]*?\$private_helper_acl_denial\$/i);

const catalogHash = "2e450238768fbe9889470864a1832486";
assert.equal(
  (Object.values(sql).join("\n").match(new RegExp(catalogHash, "g")) ?? []).length,
  6,
  "El contrato canónico de catálogos debe aparecer en los seis puntos de control",
);
for (const [catalog, count] of Object.entries({
  academic_periods: 5,
  academic_programs: 2,
  activity_modalities: 3,
  activity_statuses: 6,
  activity_types: 5,
  attention_categories: 5,
  divisions: 1,
  location_types: 7,
  participant_roles: 5,
  roles: 10,
  service_types: 2,
})) {
  assert.match(
    Object.values(sql).join("\n"),
    new RegExp(`count\\(\\*\\)\\s+filter\\(where catalog='${catalog}'\\)=${count}`),
    `Falta el cardinal exacto del catálogo ${catalog}`,
  );
}
assert.ok(
  (Object.values(sql).join("\n").match(/count\(\*\)=51/g) ?? []).length >= 6,
  "Falta el total exacto de 51 semillas en algún punto de control",
);
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
    const authorityChecks = [...match[1].matchAll(/public\.is_b1_account_admin\(\)/gi)];
    assert.ok(authorityChecks.length >= 2, "Falta la segunda comprobación de autoridad bajo bloqueo");
    const secondAuthority = authorityChecks[1].index;
    const programLock = match[1].toLowerCase().indexOf("for share", secondAuthority);
    const profileUpdate = match[1].toLowerCase().indexOf("update public.profiles", programLock);
    assert.ok(programLock > secondAuthority, "El bloqueo FOR SHARE del programa debe seguir a la segunda autorización");
    assert.ok(profileUpdate > programLock, "La mutación del perfil debe seguir al bloqueo FOR SHARE del programa");
  }
}

for (const source of Object.values(sql)) {
  assert.doesNotMatch(source, /postgres(?:ql)?:\/\/|supabase_db_url|service_role_key/i);
}

console.log("Contrato SQL estático de 0009: OK");
