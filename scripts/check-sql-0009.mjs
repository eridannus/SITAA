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
const snapshotPaths = {
  constraints: "supabase/reconciliation/live/live_constraints.sql",
  triggers: "supabase/reconciliation/live/live_triggers.sql",
  tablePrivileges: "supabase/reconciliation/live/live_table_privileges.sql",
  sequencePrivileges: "supabase/reconciliation/live/live_sequence_privileges.sql",
};
const snapshots = Object.fromEntries(Object.entries(snapshotPaths).map(([key, value]) => [
  key,
  fs.readFileSync(path.join(root, value), "utf8"),
]));

function md5(value) {
  return crypto.createHash("md5").update(value, "utf8").digest("hex");
}

function snapshotRows(source, fixedColumns) {
  return source.split(/\r?\n/)
    .filter((line) => line.length > 0 && !line.startsWith("--"))
    .map((line) => {
      const columns = line.split("\t");
      assert.ok(columns.length >= fixedColumns, `Fila de snapshot incompleta: ${line}`);
      if (columns.length === fixedColumns) return columns;
      return [...columns.slice(0, fixedColumns - 1), columns.slice(fixedColumns - 1).join("\t")];
    });
}

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
    if (lineComment) {
      if (current === "\n") lineComment = false;
      continue;
    }
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
    assert.notEqual(
      closingOffset,
      -1,
      `${label}: delimitador ${delimiter} abierto en línea ${lineAtOffset(source, openingOffset)} sin cierre`,
    );
    bodies.push({
      delimiter,
      body: source.slice(bodyOffset, closingOffset),
      openingOffset,
      closingOffset,
      openingLine: lineAtOffset(source, openingOffset),
      closingLine: lineAtOffset(source, closingOffset),
    });
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

function normalizeSqlFragment(source) {
  return source.replace(/\s+/g, "").toLowerCase();
}

function assertDefaultAclObjectTypeCast(source, label) {
  const normalized = normalizeSqlFragment(source);
  assert.match(
    normalized,
    /defaclobjtype::text/,
    `${label}: defaclobjtype debe convertirse explícitamente a text`,
  );
  assert.doesNotMatch(
    normalized,
    /\|\|defaclobjtype\|\|/,
    `${label}: defaclobjtype no puede concatenarse como pg_catalog."char"`,
  );
}

function extractDefaultAclHashCalculations(source) {
  const pattern = /\(\s*select\s+md5\s*\(\s*coalesce\s*\(\s*string_agg\s*\(\s*(defaclrole[^,\r\n]*?)\s*,\s*'\|'\s+order\s+by\s+(defaclrole\s*,\s*defaclnamespace\s*,\s*defaclobjtype)\s*\)\s*,\s*''\s*\)\s*\)\s+from\s+pg_default_acl\s*\)/gi;
  return [...source.matchAll(pattern)].map((match) => ({
    full: match[0],
    serialization: normalizeSqlFragment(match[1]),
    ordering: normalizeSqlFragment(match[2]),
    offset: match.index,
  }));
}

for (const [label, source] of Object.entries(sql)) assertLexicallyBalanced(source, label);

const dollarBodyAudit = {};
for (const label of ["migration", "verify", "rollback"]) {
  const bodies = extractDollarQuotedBodies(sql[label], label);
  for (const body of bodies) {
    assertLexicallyBalanced(
      body.body,
      `${label}:${body.delimiter} líneas ${body.openingLine}-${body.closingLine}`,
    );
  }
  dollarBodyAudit[label] = bodies;
}
assert.equal(dollarBodyAudit.migration.length, 5, "Cantidad inesperada de cuerpos dollar-quoted en migration");
assert.equal(dollarBodyAudit.verify.length, 35, "Cantidad inesperada de cuerpos dollar-quoted en verify");
assert.equal(dollarBodyAudit.rollback.length, 2, "Cantidad inesperada de cuerpos dollar-quoted en rollback");

const brokenDollarRegression = `do $preflight$
begin
  perform exists (
    select 1
    where (
      true
      or exists (select 1)
    );
end;
$preflight$;`;
const brokenRegressionBody = extractDollarQuotedBodies(brokenDollarRegression, "regresión negativa")[0];
assert.throws(
  () => assertLexicallyBalanced(brokenRegressionBody.body, "regresión negativa:$preflight$"),
  /paréntesis sin cerrar/,
);

const correctedDollarRegression = `do $preflight$
begin
  perform exists (
    select 1
    where (
      true
      or exists (select 1)
    )
  );
end;
$preflight$;`;
const correctedRegressionBody = extractDollarQuotedBodies(correctedDollarRegression, "regresión positiva")[0];
assert.doesNotThrow(
  () => assertLexicallyBalanced(correctedRegressionBody.body, "regresión positiva:$preflight$"),
);

const unsafeDefaultAclRegression = "text_value || defaclobjtype || ':'";
assert.throws(
  () => assertDefaultAclObjectTypeCast(unsafeDefaultAclRegression, "regresión negativa default ACL"),
  /defaclobjtype debe convertirse explícitamente a text/,
);
const safeDefaultAclRegression = "text_value || defaclobjtype::text || ':'";
assert.doesNotThrow(
  () => assertDefaultAclObjectTypeCast(safeDefaultAclRegression, "regresión positiva default ACL"),
);

const defaultAclCalculations = extractDefaultAclHashCalculations(sql.migration);
assert.equal(
  (sql.migration.match(/from\s+pg_default_acl/gi) ?? []).length,
  2,
  "La migración debe contener exactamente dos cálculos de hash sobre pg_default_acl",
);
assert.equal(defaultAclCalculations.length, 2, "No se extrajeron los dos cálculos default ACL esperados");
for (const [index, calculation] of defaultAclCalculations.entries()) {
  assertDefaultAclObjectTypeCast(calculation.serialization, `default ACL ${index + 1}`);
  assert.equal(
    calculation.serialization,
    "defaclrole::text||':'||defaclnamespace::text||':'||defaclobjtype::text||':'||defaclacl::text",
    `Serialización inesperada en default ACL ${index + 1}`,
  );
  assert.equal(
    calculation.ordering,
    "defaclrole,defaclnamespace,defaclobjtype",
    `Orden inesperado en default ACL ${index + 1}`,
  );
}
assert.equal(
  defaultAclCalculations[0].serialization,
  defaultAclCalculations[1].serialization,
  "Las serializaciones pre-DDL y post-DDL de default ACL deben ser equivalentes",
);
assert.equal(
  defaultAclCalculations[0].ordering,
  defaultAclCalculations[1].ordering,
  "Los órdenes pre-DDL y post-DDL de default ACL deben ser equivalentes",
);
assert.equal(
  (sql.migration.match(/defaclobjtype::text/gi) ?? []).length,
  2,
  "Los dos cálculos default ACL deben convertir defaclobjtype a text",
);
assert.doesNotMatch(
  normalizeSqlFragment(sql.migration),
  /\|\|defaclobjtype\|\|/,
  "No puede quedar una concatenación directa de defaclobjtype sin cast",
);

const defaultAclCaptureAt = sql.migration.search(/set_config\s*\(\s*'sitaa_0009\.default_acl_hash'/i);
const firstPersistentDdlAt = sql.migration.search(/^create\s+function\s+public\./im);
const postDdlGuardAt = sql.migration.search(/do\s+\$post_ddl\$/i);
const defaultAclComparisonAt = sql.migration.search(/current_setting\s*\(\s*'sitaa_0009\.default_acl_hash'\s*,\s*true\s*\)\s+is\s+distinct\s+from/i);
const commitAt = sql.migration.search(/^commit;/im);
assert.ok(
  defaultAclCaptureAt >= 0
    && defaultAclCaptureAt < defaultAclCalculations[0].offset
    && defaultAclCalculations[0].offset < firstPersistentDdlAt,
  "La línea base default ACL debe capturarse antes del primer DDL persistente",
);
assert.ok(
  postDdlGuardAt >= 0
    && postDdlGuardAt < defaultAclComparisonAt
    && defaultAclComparisonAt < defaultAclCalculations[1].offset
    && defaultAclCalculations[1].offset < commitAt,
  "La comparación default ACL debe permanecer en la guarda post-DDL antes de COMMIT",
);
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

const allSql = Object.values(sql).join("\n");
const constraintMapPretty = /string_agg\([^\r\n]*pg_get_constraintdef\(constraint_definition\.oid\s*,\s*true\)[^\r\n]*64f099164063d0cf500478dda3b5d25c/gi;
const constraintMapDefault = /string_agg\([^\r\n]*pg_get_constraintdef\(constraint_definition\.oid\s*\)(?!\s*,\s*true)/gi;
const triggerMapPretty = /string_agg\([^\r\n]*pg_get_triggerdef\(trigger_definition\.oid\s*,\s*true\)[^\r\n]*67ee47bcd43c0594129facf3d7729bad/gi;
const triggerMapFalse = /string_agg\([^\r\n]*pg_get_triggerdef\(trigger_definition\.oid\s*,\s*false\)/gi;
const authWhenFalse = /split_part\(split_part\(lower\(pg_get_triggerdef\(trigger_definition\.oid\s*,\s*false\)\)/gi;
assert.equal((allSql.match(constraintMapPretty) ?? []).length, 6, "Los seis mapas de restricciones deben usar pretty=true");
assert.equal((allSql.match(constraintMapDefault) ?? []).length, 0, "Ningún mapa completo de restricciones puede usar el deparser por defecto");
assert.equal((allSql.match(triggerMapPretty) ?? []).length, 6, "Los seis mapas públicos de triggers deben usar pretty=true");
assert.equal((allSql.match(triggerMapFalse) ?? []).length, 0, "El mapa agregado de triggers no puede usar pretty=false");
assert.equal((allSql.match(authWhenFalse) ?? []).length, 6, "Los seis parsers especializados Auth WHEN deben conservar pretty=false");
assert.doesNotMatch(allSql, /information_schema\.usage_privileges/i);
assert.doesNotMatch(allSql, /information_schema\.role_table_grants/i);
assert.doesNotMatch(allSql, /017b6a7c8048ffdfdc0b7d7319b59a92/i);
assert.equal((allSql.match(/edbb0931514cafe989d3d345c4ea61d6/gi) ?? []).length, 6, "El hash post-0008 debe estar en las seis superficies");
assert.equal((allSql.match(/(?:select )?\(select count\(\*\) from (?:sequence_acl_actual|actual)\)=6 and not exists/gi) ?? []).length, 6, "Falta el contrato bidireccional de seis ACL de secuencia");
assert.equal((allSql.match(/\('public','system_health_id_seq','postgres','(?:postgres|service_role)','(?:SELECT|UPDATE|USAGE)',false\)/g) ?? []).length, 36, "Cada superficie debe declarar exactamente las seis ACL de secuencia");
assert.equal((allSql.match(/(?:select )?\(select count\(\*\) from (?:authenticated_table_grant_actual|actual)\)=19 and not exists/gi) ?? []).length, 6, "Falta el contrato bidireccional de diecinueve grants authenticated");
assert.equal((allSql.match(/\('activity_participants','SELECT','postgres','authenticated','NO','YES'\)/g) ?? []).length, 6, "activity_participants debe conservar sólo SELECT en cada superficie");
assert.doesNotMatch(allSql, /\('activity_participants','(?:INSERT|UPDATE|DELETE)'/i);
assert.equal((allSql.match(/admin_audit_events_action_code_check[\s\S]{0,600}?pg_get_constraintdef\(constraint_definition\.oid\s*,\s*true\)/gi) ?? []).length, 6, "La restricción action_code debe compararse en pretty=true seis veces");
assert.equal((allSql.match(/constraint_definition\.contype='c' and constraint_definition\.convalidated/gi) ?? []).length, 6, "La restricción action_code debe ser CHECK validada en cada superficie");
assert.equal((allSql.match(/attribute_definition\.attname='action_code'/gi) ?? []).length, 6, "La restricción action_code debe estar ligada sólo a action_code");
assert.equal((allSql.match(/'account_deactivated'~'\^\[a-z\]/g) ?? []).length, 6, "Falta la regresión account_deactivated en alguna superficie");
assert.equal((allSql.match(/'account_reactivated'~'\^\[a-z\]/g) ?? []).length, 6, "Falta la regresión account_reactivated en alguna superficie");

const constraintRows = snapshotRows(snapshots.constraints, 4).sort((left, right) =>
  left[0].localeCompare(right[0]) || left[1].localeCompare(right[1]));
assert.equal(constraintRows.length, 80);
assert.equal(md5(constraintRows.map((row) => row.join(":")).join("|")), "64f099164063d0cf500478dda3b5d25c");
const actionConstraint = constraintRows.filter((row) => row[0] === "admin_audit_events" && row[1] === "admin_audit_events_action_code_check");
assert.deepEqual(actionConstraint, [[
  "admin_audit_events",
  "admin_audit_events_action_code_check",
  "check",
  "CHECK (char_length(action_code) >= 1 AND char_length(action_code) <= 100 AND action_code ~ '^[a-z][a-z0-9]*(_[a-z0-9]+)*$'::text)",
]]);

const triggerRows = snapshotRows(snapshots.triggers, 3).sort((left, right) =>
  left[0].localeCompare(right[0]) || left[1].localeCompare(right[1]));
assert.equal(triggerRows.length, 11);
assert.equal(md5(triggerRows.map((row) => row.join(":")).join("|")), "67ee47bcd43c0594129facf3d7729bad");

const authenticatedTableRows = snapshotRows(snapshots.tablePrivileges, 7)
  .filter((row) => row[3] === "authenticated")
  .sort((left, right) => left[1].localeCompare(right[1]) || left[4].localeCompare(right[4]));
assert.equal(authenticatedTableRows.length, 19);
assert.equal(md5(authenticatedTableRows.map((row) => `${row[1]}:${row[4]}`).join("|")), "edbb0931514cafe989d3d345c4ea61d6");
assert.deepEqual(
  authenticatedTableRows.filter((row) => row[1] === "activity_participants").map((row) => row[4]),
  ["SELECT"],
);
assert.deepEqual(
  authenticatedTableRows.filter((row) => row[1] === "profiles").map((row) => row[4]),
  ["SELECT"],
);

const sequenceRows = snapshotRows(snapshots.sequencePrivileges, 6);
assert.deepEqual(sequenceRows, [
  ["public", "system_health_id_seq", "postgres", "postgres", "SELECT", "false"],
  ["public", "system_health_id_seq", "postgres", "postgres", "UPDATE", "false"],
  ["public", "system_health_id_seq", "postgres", "postgres", "USAGE", "false"],
  ["public", "system_health_id_seq", "postgres", "service_role", "SELECT", "false"],
  ["public", "system_health_id_seq", "postgres", "service_role", "UPDATE", "false"],
  ["public", "system_health_id_seq", "postgres", "service_role", "USAGE", "false"],
]);

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

console.log(`Cuerpos dollar-quoted validados: migration=${dollarBodyAudit.migration.length}, verify=${dollarBodyAudit.verify.length}, rollback=${dollarBodyAudit.rollback.length}`);
console.log("Regresiones dollar-quoted: negativa rechazada; positiva aceptada");
console.log(`Default ACL hash typing: ${defaultAclCalculations.length}/2 explicitly cast and equivalent`);
console.log("Regresiones default ACL: negativa rechazada; positiva aceptada");
console.log("Contrato SQL estático de 0009: OK");
