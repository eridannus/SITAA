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
const coreArtifacts = [
  artifacts.migration,
  artifacts.preflight,
  artifacts.verify,
  artifacts.rollback,
  "supabase/functions/admin-account-auth-lifecycle/index.ts",
  "supabase/functions/admin-account-auth-lifecycle/auth-admin-adapter.ts",
  "supabase/config.toml",
  "scripts/check-auth-lifecycle-b3a.mjs",
  "scripts/check-sql-0010.mjs",
  "docs/TEST_PLAN_0010.md",
  "app/admin/accounts/[id]/lifecycle/page.tsx",
  "app/admin/accounts/[id]/lifecycle/actions.ts",
  "app/admin/accounts/[id]/lifecycle/account-lifecycle-form.tsx",
  "lib/admin/account-lifecycle.ts",
  "lib/admin/account-lifecycle-permissions.ts",
  "types/admin.ts",
];
const sources = Object.fromEntries(Object.entries(artifacts).map(([key, relative]) => [key, fs.readFileSync(path.join(root, relative), "utf8")]));
const edge = fs.readFileSync(path.join(root, "supabase/functions/admin-account-auth-lifecycle/index.ts"), "utf8");
const adapter = fs.readFileSync(path.join(root, "supabase/functions/admin-account-auth-lifecycle/auth-admin-adapter.ts"), "utf8");

function immutableTextSha256(text) {
  const canonicalLfText = text.replace(/\r\n/g, "\n").replace(/\r/g, "\n");
  return crypto.createHash("sha256").update(canonicalLfText, "utf8").digest("hex");
}

function immutableTextArtifactSha256(filePath) {
  return immutableTextSha256(fs.readFileSync(filePath, "utf8"));
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

const roleIntervalPattern = /set\s+local\s+role\s+(authenticated|service_role)\s*;([\s\S]*?)reset\s+role\s*;/gi;
const protectedTablePattern = /\b(?:public\.)?(admin_auth_operations|admin_audit_events|profiles|role_assignments|activities|activity_participants)\b|\bauth\.(users|identities)\b/gi;
const b3aRpcPattern = /public\.(get_admin_account_auth_lifecycle_context_b3a|prepare_admin_account_auth_lifecycle_b3a|finalize_admin_account_auth_reactivation_b3a|claim_admin_auth_operation_b3a|record_admin_auth_operation_result_b3a|transition_admin_account_lifecycle_b2b)\b/gi;
const allowedAclDenialBlocks = [
  /begin\s+perform 1 from public\.admin_auth_operations;\s+raise exception '0010_verify_authenticated_table_read_unexpected';\s+exception when insufficient_privilege then null;\s+end;/gi,
  /begin\s+perform 1 from public\.admin_auth_operations;\s+raise exception '0010_verify_service_table_read_unexpected';\s+exception when insufficient_privilege then null;\s+end;/gi,
];

function auditVerifierRoleIntervals(source, label, failOnUnauthorized = true) {
  const counts = { authenticated: 0, service_role: 0 };
  let protectedRawReferences = 0;
  let allowlistedNegativeReferences = 0;
  const unauthorized = [];
  for (const interval of source.matchAll(roleIntervalPattern)) {
    const role = interval[1];
    counts[role] += 1;
    const originalBody = interval[2];
    protectedRawReferences += (originalBody.match(protectedTablePattern) ?? []).length;
    let auditedBody = originalBody;
    for (const allowlistPattern of allowedAclDenialBlocks) {
      auditedBody = auditedBody.replace(allowlistPattern, (block) => {
        allowlistedNegativeReferences += (block.match(protectedTablePattern) ?? []).length;
        return "";
      });
    }
    for (const reference of auditedBody.matchAll(protectedTablePattern)) {
      unauthorized.push({
        role,
        reference: reference[0],
        line: lineAtOffset(source, interval.index + reference.index),
      });
    }
    const allowedRpcs = role === "authenticated"
      ? new Set([
        "get_admin_account_auth_lifecycle_context_b3a",
        "prepare_admin_account_auth_lifecycle_b3a",
        "finalize_admin_account_auth_reactivation_b3a",
      ])
      : new Set([
        "claim_admin_auth_operation_b3a",
        "record_admin_auth_operation_result_b3a",
      ]);
    for (const rpc of originalBody.matchAll(b3aRpcPattern)) {
      const rpcName = rpc[1];
      const exactLegacyDenial = role === "authenticated"
        && rpcName === "transition_admin_account_lifecycle_b2b"
        && originalBody.includes("0010_verify_direct_b2b_unexpected")
        && originalBody.includes("exception when insufficient_privilege then null");
      if (!allowedRpcs.has(rpcName) && !exactLegacyDenial) {
        unauthorized.push({
          role,
          reference: `RPC ${rpcName}`,
          line: lineAtOffset(source, interval.index + rpc.index),
        });
      }
    }
  }
  if (failOnUnauthorized) {
    assert.equal(
      unauthorized.length,
      0,
      `${label}: referencias protegidas no autorizadas: ${unauthorized.map((entry) =>
        `${entry.role}:${entry.reference}@${entry.line}`).join(", ")}`,
    );
  }
  return { counts, protectedRawReferences, allowlistedNegativeReferences, unauthorized };
}

const rawAuthenticatedFixture = `
set local role authenticated;
select * from public.admin_auth_operations;
reset role;`;
const rawServiceFixture = `
set local role service_role;
select * from public.admin_auth_operations;
reset role;`;
const updateServiceFixture = `
set local role service_role;
update public.admin_auth_operations set status='succeeded';
reset role;`;
const wrongRoleRpcFixture = `
set local role authenticated;
select * from public.claim_admin_auth_operation_b3a(gen_random_uuid(),gen_random_uuid());
reset role;`;
const ownerPostconditionFixture = `
set local role authenticated;
select * from public.get_admin_account_auth_lifecycle_context_b3a(gen_random_uuid());
reset role;
select * from public.admin_auth_operations;`;
const exactAclDenialFixture = `
set local role authenticated;
do $$ begin
  begin perform 1 from public.admin_auth_operations; raise exception '0010_verify_authenticated_table_read_unexpected';
  exception when insufficient_privilege then null; end;
end $$;
reset role;`;
assert.equal(auditVerifierRoleIntervals(rawAuthenticatedFixture, "fixture authenticated", false).unauthorized.length, 1);
assert.equal(auditVerifierRoleIntervals(rawServiceFixture, "fixture service SELECT", false).unauthorized.length, 1);
assert.equal(auditVerifierRoleIntervals(updateServiceFixture, "fixture service UPDATE", false).unauthorized.length, 1);
assert.equal(auditVerifierRoleIntervals(wrongRoleRpcFixture, "fixture RPC por rol", false).unauthorized.length, 1);
assert.equal(auditVerifierRoleIntervals(ownerPostconditionFixture, "fixture owner", false).unauthorized.length, 0);
const allowedFixtureAudit = auditVerifierRoleIntervals(exactAclDenialFixture, "fixture ACL", false);
assert.equal(allowedFixtureAudit.unauthorized.length, 0);
assert.equal(allowedFixtureAudit.allowlistedNegativeReferences, 1);

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

const internalCatalogCharNames = [
  "prokind", "provolatile", "proparallel", "relkind", "contype",
  "confupdtype", "confdeltype", "confmatchtype", "tgenabled",
  "defaclobjtype", "attidentity", "attgenerated", "typtype", "typcategory",
];
const internalCatalogCharPattern = new RegExp(
  `(?:\\b[a-z_][a-z0-9_]*\\.)?(${internalCatalogCharNames.join("|")})\\b(\\s*::\\s*text)?`,
  "gi",
);
function auditInternalCatalogCharConcatenation(source) {
  const result = { expressionsAudited: 0, safeExplicitCasts: 0, unsafe: [] };
  for (const match of source.matchAll(internalCatalogCharPattern)) {
    const end = match.index + match[0].length;
    const adjacentToConcat = source.slice(0, match.index).trimEnd().endsWith("||")
      || source.slice(end).trimStart().startsWith("||");
    if (!adjacentToConcat) continue;
    result.expressionsAudited += 1;
    if (match[2]) result.safeExplicitCasts += 1;
    else result.unsafe.push({ expression: match[0], line: lineAtOffset(source, match.index) });
  }
  return result;
}
const unsafeCatalogRegression = [
  "text_value || p.provolatile",
  "text_value || ':' || tgenabled || ':'",
  "defaclrole::text || defaclobjtype",
].join("\n");
const safeCatalogRegression = [
  "text_value || p.provolatile::text",
  "text_value || ':' || tgenabled::text || ':'",
  "defaclrole::text || defaclobjtype::text",
].join("\n");
assert.equal(auditInternalCatalogCharConcatenation(unsafeCatalogRegression).unsafe.length, 3);
assert.equal(auditInternalCatalogCharConcatenation(safeCatalogRegression).unsafe.length, 0);
assert.equal(auditInternalCatalogCharConcatenation(safeCatalogRegression).safeExplicitCasts, 3);
const internalCatalogCharAudit = { expressionsAudited: 0, safeExplicitCasts: 0, unsafe: [] };
for (const [name, source] of Object.entries(sources)) {
  const audit = auditInternalCatalogCharConcatenation(source);
  internalCatalogCharAudit.expressionsAudited += audit.expressionsAudited;
  internalCatalogCharAudit.safeExplicitCasts += audit.safeExplicitCasts;
  internalCatalogCharAudit.unsafe.push(...audit.unsafe.map((entry) => ({ ...entry, artifact: name })));
}
assert.equal(
  internalCatalogCharAudit.unsafe.length,
  0,
  `Concatenaciones inseguras de catálogo: ${internalCatalogCharAudit.unsafe.map((entry) =>
    `${entry.artifact}:${entry.line}:${entry.expression}`).join(", ")}`,
);

function assertRequestIdCatalogContract(source, label) {
  const obsoleteIndexName = ["admin_auth_operations_request_id", "uidx"].join("_");
  assert.match(
    source,
    /constraint admin_auth_operations_request_id_key unique \(request_id\)/,
    `${label}: request_id debe declararse como restricción UNIQUE dentro de CREATE TABLE`,
  );
  assert.equal(source.includes(obsoleteIndexName), false, `${label}: sobrevive el nombre de índice obsoleto`);
  assert.doesNotMatch(
    source,
    /unique\s+using\s+index/i,
    `${label}: no se permite acoplar nombres distintos mediante UNIQUE USING INDEX`,
  );
}

const mismatchedRequestIdRegression = `
create table public.admin_auth_operations (
  request_id uuid not null,
  constraint admin_auth_operations_request_id_key unique (request_id)
);
create unique index admin_auth_operations_request_id_source_idx
  on public.admin_auth_operations(request_id);
alter table public.admin_auth_operations
  add constraint admin_auth_operations_request_id_second_key
  unique using index admin_auth_operations_request_id_source_idx;`;
assert.throws(
  () => assertRequestIdCatalogContract(mismatchedRequestIdRegression, "regresión negativa request_id"),
  /UNIQUE USING INDEX/,
);
assertRequestIdCatalogContract(sources.migration, "migration");

function sliceBetween(source, startToken, endToken, label) {
  const start = source.indexOf(startToken);
  const end = source.indexOf(endToken, start + startToken.length);
  assert.ok(start >= 0 && end > start, `No se pudo extraer ${label}`);
  return source.slice(start, end);
}

function topLevelCategories(source, spaces) {
  const pattern = new RegExp(`^${" ".repeat(spaces)}\\('([a-z0-9_]+)'\\s*,`, "gm");
  return [...source.matchAll(pattern)].map((match) => match[1]);
}

function extractCategoryDefinition(source, category) {
  const marker = `('${category}',`;
  const start = source.indexOf(marker);
  assert.ok(start >= 0, `No se encontró la categoría ${category}`);
  let depth = 0;
  let single = false;
  for (let index = start; index < source.length; index += 1) {
    const current = source[index];
    if (current === "'") {
      if (single && source[index + 1] === "'") {
        index += 1;
        continue;
      }
      single = !single;
      continue;
    }
    if (single) continue;
    if (current === "(") depth += 1;
    if (current === ")") {
      depth -= 1;
      if (depth === 0) return source.slice(start, index + 1);
    }
  }
  assert.fail(`No se pudo cerrar la categoría ${category}`);
}

function normalizedSql(source) {
  return source.replace(/\s+/g, "");
}

const independentBlocking = sliceBetween(
  sources.preflight,
  "with blocking(category,aggregate_count) as (",
  "), informational(category,aggregate_count) as (",
  "superficie bloqueante independiente",
);
const embeddedBlocking = sliceBetween(
  sources.migration,
  "with canonical_blocking(category,aggregate_count) as (",
  "select count(*) into mismatch_count",
  "superficie bloqueante embebida",
);
const independentCategories = topLevelCategories(independentBlocking, 2);
const embeddedCategories = topLevelCategories(embeddedBlocking, 4);
const independentInformational = sliceBetween(
  sources.preflight,
  "), informational(category,aggregate_count) as (",
  ")\nselect category,'blocking'::text",
  "superficie informativa independiente",
);
const informationalCategories = topLevelCategories(independentInformational, 2);
assert.equal(independentCategories.length, 30, "El preflight debe conservar 30 categorías bloqueantes");
assert.equal(informationalCategories.length, 4, "El preflight debe conservar 4 categorías informativas");
assert.deepEqual(
  embeddedCategories,
  independentCategories,
  "El preflight embebido debe reproducir todas las categorías bloqueantes independientes y en el mismo orden",
);
const independentDangerousDefaultAcl = extractCategoryDefinition(
  independentBlocking,
  "dangerous_default_acl",
);
const embeddedDangerousDefaultAcl = extractCategoryDefinition(
  embeddedBlocking,
  "dangerous_default_acl",
);
assert.equal(
  normalizedSql(embeddedDangerousDefaultAcl),
  normalizedSql(independentDangerousDefaultAcl),
  "dangerous_default_acl debe ser idéntica en preflight independiente y embebido",
);
for (const requiredContract of [
  /current_user::text<>'postgres'/,
  /session_user::text<>'postgres'/,
  /d\.defaclrole='postgres'::regrole/,
  /d\.defaclnamespace=0/,
  /d\.defaclnamespace='public'::regnamespace/,
  /d\.defaclobjtype::text in \('r','f'\)/,
  /a\.grantee not in \(\s*0,'anon'::regrole,'authenticated'::regrole,'service_role'::regrole,'postgres'::regrole\s*\)/,
]) {
  assert.match(independentDangerousDefaultAcl, requiredContract);
}
assert.doesNotMatch(
  independentDangerousDefaultAcl,
  /\b(?:supabase_admin|storage|graphql|graphql_public)\b/,
  "La categoría no debe enumerar propietarios ni esquemas ajenos",
);
assert.doesNotMatch(
  independentDangerousDefaultAcl,
  /defaclobjtype::text\s*(?:=|in)\s*\([^)]*'S'/,
  "La categoría no debe consumir defaults de secuencia",
);
assert.doesNotMatch(
  independentDangerousDefaultAcl,
  /privilege_type/,
  "Todo privilegio de un grantee inesperado debe bloquear, no sólo una lista parcial",
);
const independentCanonicalHashes = [...new Set(independentBlocking.match(/\b[a-f0-9]{32}\b/g) ?? [])];
for (const hash of independentCanonicalHashes) {
  assert.ok(embeddedBlocking.includes(hash), `Hash canónico presente sólo en preflight independiente: ${hash}`);
}
assert.ok(
  sources.migration.indexOf("sitaa_0010_preflight_canonical_baseline_mismatch")
    < sources.migration.indexOf("set_config('sitaa_0010.prior_"),
  "La migración no puede capturar hashes transaccionales antes de aprobar el baseline canónico",
);

assert.match(sources.migration, /^--[\s\S]*\nbegin;/);
assert.match(sources.migration.trimEnd(), /commit;$/);
assert.match(sources.preflight, /begin transaction read only;/);
assert.match(sources.preflight.trimEnd(), /rollback;$/);
for (const [artifact, source] of Object.entries(sources)) {
  assert.doesNotMatch(
    source,
    /alter\s+default\s+privileges/i,
    `${artifact}: 0010 no puede alterar privilegios predeterminados`,
  );
}
assert.match(
  sources.migration,
  /set_config\('sitaa_0010\.default_acl_hash',[\s\S]*from pg_default_acl\),true\)/,
  "La migración debe capturar el hash completo de pg_default_acl",
);
assert.match(
  sources.migration,
  /current_setting\('sitaa_0010\.default_acl_hash',true\) is distinct from[\s\S]*from pg_default_acl/,
  "La guarda final debe comparar nuevamente el hash completo de pg_default_acl",
);

const ledgerCreate = sources.migration.indexOf("create table public.admin_auth_operations (");
const ledgerRls = sources.migration.indexOf(
  "alter table public.admin_auth_operations enable row level security;",
  ledgerCreate,
);
const ledgerKnownRevoke = sources.migration.indexOf(
  "revoke all on table public.admin_auth_operations from public,anon,authenticated,service_role;",
  ledgerRls,
);
const ledgerDynamicRevoke = sources.migration.indexOf("do $normalize_ledger_acl$", ledgerKnownRevoke);
const ledgerDynamicRevokeStatement = sources.migration.indexOf(
  "execute format('revoke all privileges on table public.admin_auth_operations from %I',grantee_name);",
  ledgerDynamicRevoke,
);
const ledgerDynamicRevokeEnd = sources.migration.indexOf(
  "$normalize_ledger_acl$;",
  ledgerDynamicRevoke,
);
const ledgerOwnerGrant = sources.migration.indexOf(
  "grant all privileges on table public.admin_auth_operations to postgres;",
  ledgerDynamicRevokeStatement,
);
const ledgerPostAcl = sources.migration.indexOf(
  "and (select count(*) from aclexplode(table_definition.relacl) acl",
  ledgerOwnerGrant,
);
const migrationCommit = sources.migration.lastIndexOf("commit;");
for (const [previous, next, label] of [
  [ledgerCreate, ledgerRls, "CREATE TABLE -> RLS"],
  [ledgerRls, ledgerKnownRevoke, "RLS -> revocación conocida"],
  [ledgerKnownRevoke, ledgerDynamicRevoke, "revocación conocida -> normalización dinámica"],
  [ledgerDynamicRevoke, ledgerDynamicRevokeStatement, "inicio -> revocación dinámica"],
  [ledgerDynamicRevokeStatement, ledgerDynamicRevokeEnd, "revocación dinámica -> cierre"],
  [ledgerDynamicRevokeEnd, ledgerOwnerGrant, "normalización dinámica -> grant owner"],
  [ledgerOwnerGrant, ledgerPostAcl, "grant owner -> guarda ACL"],
  [ledgerPostAcl, migrationCommit, "guarda ACL -> COMMIT"],
]) {
  assert.ok(previous >= 0 && next > previous, `Orden ACL del ledger inválido: ${label}`);
}
const ledgerDynamicNormalization = sources.migration.slice(
  ledgerDynamicRevoke,
  ledgerDynamicRevokeEnd,
);
assert.match(
  ledgerDynamicNormalization,
  /aclexplode\(coalesce\(table_definition\.relacl,acldefault\('r',table_definition\.relowner\)\)\)/,
);
assert.match(
  ledgerDynamicNormalization,
  /acl\.grantee<>table_definition\.relowner and acl\.grantee<>0/,
);
const ledgerPostAclDefinition = sources.migration.slice(ledgerPostAcl, migrationCommit);
assert.match(ledgerPostAclDefinition, /acl\.grantee=table_definition\.relowner[\s\S]*\)=8/);
assert.match(ledgerPostAclDefinition, /count\(\*\) from aclexplode\(table_definition\.relacl\)\)=8/);

const functionAclContracts = [
  ["guard_admin_auth_operation_b3a()", null],
  ["get_admin_account_auth_lifecycle_context_b3a(uuid)", "authenticated"],
  ["prepare_admin_account_auth_lifecycle_b3a(uuid,text,text,uuid)", "authenticated"],
  ["finalize_admin_account_auth_reactivation_b3a(uuid)", "authenticated"],
  ["claim_admin_auth_operation_b3a(uuid,uuid)", "service_role"],
  ["record_admin_auth_operation_result_b3a(uuid,uuid,integer,text,text)", "service_role"],
];
for (const [signature, approvedRole] of functionAclContracts) {
  assert.ok(
    sources.migration.includes(
      `revoke all on function public.${signature} from public,anon,authenticated,service_role;`,
    ),
    `Falta revocación explícita de ${signature}`,
  );
  if (approvedRole) {
    assert.ok(
      sources.migration.includes(`grant execute on function public.${signature} to ${approvedRole};`),
      `Falta grant aprobado de ${signature}`,
    );
  }
}
assert.match(
  sources.migration,
  /with expected\(function_oid,grantee\) as \([\s\S]*select \* from expected except select \* from actual[\s\S]*select \* from actual except select \* from expected/,
);

const normalizedDefaultAclGrantees = new Set([
  "PUBLIC",
  "anon",
  "authenticated",
  "service_role",
  "postgres",
]);
function dangerousDefaultAclFixture(rows, currentUser = "postgres", sessionUser = "postgres") {
  if (currentUser !== "postgres" || sessionUser !== "postgres") return 1;
  return rows.filter((row) =>
    row.owner === "postgres"
      && (row.schema === "global" || row.schema === "public")
      && (row.objectType === "r" || row.objectType === "f")
      && !normalizedDefaultAclGrantees.has(row.grantee)).length;
}
function platformDefaultAclGroup(owner, schema) {
  const rows = [];
  for (const grantee of ["anon", "authenticated"]) {
    rows.push({ owner, schema, objectType: "S", grantee, privilege: "UPDATE" });
    for (const privilege of ["INSERT", "UPDATE", "DELETE", "TRUNCATE"]) {
      rows.push({ owner, schema, objectType: "r", grantee, privilege });
    }
  }
  return rows;
}
const currentPlatformDefaultAclFixture = [
  ...platformDefaultAclGroup("postgres", "public"),
  ...platformDefaultAclGroup("postgres", "storage"),
  ...platformDefaultAclGroup("supabase_admin", "graphql"),
  ...platformDefaultAclGroup("supabase_admin", "graphql_public"),
  ...platformDefaultAclGroup("supabase_admin", "public"),
];
assert.equal(currentPlatformDefaultAclFixture.length, 50);
assert.equal(dangerousDefaultAclFixture(currentPlatformDefaultAclFixture), 0);
const customDefaultAclFixtures = [
  {
    label: "tabla postgres/global",
    row: { owner: "postgres", schema: "global", objectType: "r", grantee: "custom_role", privilege: "SELECT" },
  },
  {
    label: "tabla postgres/public",
    row: { owner: "postgres", schema: "public", objectType: "r", grantee: "custom_role", privilege: "INSERT" },
  },
  {
    label: "función postgres/global",
    row: { owner: "postgres", schema: "global", objectType: "f", grantee: "custom_role", privilege: "EXECUTE" },
  },
  {
    label: "función postgres/public",
    row: { owner: "postgres", schema: "public", objectType: "f", grantee: "custom_role", privilege: "EXECUTE" },
  },
];
for (const fixture of customDefaultAclFixtures) {
  assert.equal(dangerousDefaultAclFixture([fixture.row]), 1, fixture.label);
}
assert.equal(
  dangerousDefaultAclFixture([
    { owner: "postgres", schema: "global", objectType: "S", grantee: "custom_role", privilege: "UPDATE" },
  ]),
  0,
  "Un default de secuencia no aplica a 0010",
);
assert.equal(dangerousDefaultAclFixture([], "authenticated", "postgres"), 1);
assert.equal(dangerousDefaultAclFixture([], "postgres", "authenticated"), 1);
for (const category of [
  "post_0009_inventory_drift",
  "post_0009_function_signature_drift",
  "post_0009_function_map_drift",
  "post_0009_function_metadata_drift",
  "post_0009_function_acl_drift",
  "post_0009_column_hash_drift",
  "post_0009_constraint_hash_drift",
  "post_0009_index_hash_drift",
  "post_0009_trigger_hash_drift",
  "post_0009_policy_hash_drift",
  "post_0009_table_acl_drift",
  "post_0009_explicit_column_acl_drift",
  "post_0009_sequence_acl_exact_drift",
  "canonical_auth_trigger_drift",
  "admin_audit_contract_drift",
  "controlled_seed_drift",
  "conflicting_0010_table",
  "conflicting_0010_functions",
]) {
  assert.ok(sources.preflight.includes(`'${category}'`), `Preflight incompleto: ${category}`);
}
assert.match(sources.preflight, /metadata_hash|c2095a58fb96e7387513b4bebf33b95d|post_0009_function_metadata_drift/);
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
for (const canonicalHash of [
  "c2095a58fb96e7387513b4bebf33b95d",
  "e1e24e4406a6b72e539a412396b58a83",
  "f33fd097dfc9ed8a316ad5a3accab896",
]) {
  assert.ok(
    sources.rollback.split(canonicalHash).length - 1 >= 2,
    `Rollback debe comprobar ${canonicalHash} antes de destruir y después de restaurar`,
  );
}
const predestructiveStart = sources.rollback.indexOf("do $predestructive$");
const predestructiveEnd = sources.rollback.indexOf("$predestructive$;", predestructiveStart);
const postRollbackStart = sources.rollback.indexOf("do $post_rollback$");
const postRollbackEnd = sources.rollback.indexOf("$post_rollback$;", postRollbackStart);
assert.ok(predestructiveStart >= 0 && predestructiveEnd > predestructiveStart);
assert.ok(postRollbackStart >= 0 && postRollbackEnd > postRollbackStart);
const predestructive = sources.rollback.slice(predestructiveStart, predestructiveEnd);
const postRollback = sources.rollback.slice(postRollbackStart, postRollbackEnd);
assert.match(predestructive, /count\(\*\)=135[\s\S]*5c2ce865124e0669c787d12fe4c46b59/);
assert.match(
  predestructive,
  /p\.oid<>'public\.transition_admin_account_lifecycle_b2b\(uuid,text,text\)'::regprocedure[\s\S]*p\.proname not in/,
);
assert.doesNotMatch(predestructive, /count\(\*\)=137|4ea1d04b7d1b1632fd5ce01a1dc83e05/);
assert.match(
  predestructive,
  /transition_admin_account_lifecycle_b2b\(uuid,text,text\)[\s\S]*acl\.grantee=p\.proowner[\s\S]*not acl\.is_grantable[\s\S]*<>1/,
);
assert.match(
  predestructive,
  /acl\.privilege_type<>'EXECUTE'[\s\S]*acl\.grantee<>p\.proowner[\s\S]*acl\.is_grantable/,
);
assert.match(postRollback, /count\(\*\)=137[\s\S]*4ea1d04b7d1b1632fd5ce01a1dc83e05/);
assert.equal(sources.rollback.split("4ea1d04b7d1b1632fd5ce01a1dc83e05").length - 1, 1);

function exactAclSetMatches(expected, actual) {
  return expected.length === actual.length
    && expected.every((entry) => actual.includes(entry))
    && actual.every((entry) => expected.includes(entry));
}
const expectedOwnerOnlyMutationAcl = ["transition:postgres:EXECUTE:false"];
assert.equal(exactAclSetMatches(expectedOwnerOnlyMutationAcl, expectedOwnerOnlyMutationAcl), true);
assert.equal(
  exactAclSetMatches(expectedOwnerOnlyMutationAcl, ["transition:authenticated:EXECUTE:false"]),
  false,
  "Una sustitución de grantee con igual cardinalidad debe rechazarse",
);
assert.match(sources.rollback, /sitaa_0010_rollback_canonical_acl_mismatch/);
assert.match(sources.rollback, /sitaa_0010_rollback_post_0009_acl_mismatch/);
assert.ok(
  sources.rollback.split("('profiles','first_names','postgres','authenticated','UPDATE',false)").length - 1 >= 4,
  "Rollback debe comparar bidireccionalmente las ACL de columna antes y después",
);
assert.match(sources.migration, /with expected\(function_oid,grantee\)/, "La guarda 0010 debe comparar ACL exacta");
assert.match(sources.verify, /with expected\(function_oid,grantee\)/, "El verificador debe comparar ACL exacta");
assert.match(sources.migration, /sitaa_0010_post_ddl_function_body_mismatch/);
assert.match(sources.verify, /0010_verify_function_body_mismatch/);
assert.match(sources.migration, /public\.guard_admin_auth_operation_b3a\(\)'::regprocedure::oid,'postgres'::regrole::oid/);
assert.match(sources.verify, /public\.guard_admin_auth_operation_b3a\(\)'::regprocedure::oid,'postgres'::regrole::oid/);
assert.doesNotMatch(`${sources.migration}\n${sources.verify}`, /has_function_privilege\('PUBLIC'/i);
assert.match(sources.migration, /id:uuid:NO\|request_id:uuid:NO[\s\S]*updated_at:timestamp with time zone:NO/);
for (const constraint of [
  "admin_auth_operations_pkey",
  "admin_auth_operations_request_id_key",
  "admin_auth_operations_requested_by_profile_id_fkey",
  "admin_auth_operations_completed_by_profile_id_fkey",
  "admin_auth_operations_target_profile_id_fkey",
  "admin_auth_operations_profile_audit_event_id_fkey",
  "admin_auth_operations_auth_audit_event_id_fkey",
  "admin_auth_operations_operation_check",
  "admin_auth_operations_status_check",
  "admin_auth_operations_stage_check",
  "admin_auth_operations_reason_check",
  "admin_auth_operations_attempt_check",
  "admin_auth_operations_error_check",
  "admin_auth_operations_stage_operation_check",
  "admin_auth_operations_evidence_check",
  "admin_auth_operations_timestamp_check",
]) {
  for (const artifact of ["migration", "verify", "rollback"]) {
    assert.ok(sources[artifact].includes(constraint), `Falta restricción exacta en ${artifact}: ${constraint}`);
  }
}
for (const index of [
  "admin_auth_operations_pkey",
  "admin_auth_operations_request_id_key",
  "admin_auth_operations_target_status_idx",
  "admin_auth_operations_actor_requested_idx",
  "admin_auth_operations_one_nonfinal_target_uidx",
]) {
  for (const artifact of ["migration", "verify", "rollback"]) {
    assert.ok(sources[artifact].includes(index), `Falta índice exacto en ${artifact}: ${index}`);
  }
}
const obsoleteRequestIndexName = ["admin_auth_operations_request_id", "uidx"].join("_");
for (const artifact of ["migration", "verify", "rollback"]) {
  assert.equal(
    sources[artifact].includes(obsoleteRequestIndexName),
    false,
    `Sobrevive el índice request_id obsoleto en ${artifact}`,
  );
  assert.match(
    sources[artifact],
    /constraint_definition\.conindid='public\.admin_auth_operations_request_id_key'::regclass/,
    `Falta verificar conindid de request_id en ${artifact}`,
  );
  assert.match(
    sources[artifact],
    /index_definition\.indisunique[\s\S]{0,180}index_definition\.indisvalid[\s\S]{0,180}index_definition\.indisready/,
    `Falta verificar que el índice request_id sea único, válido y listo en ${artifact}`,
  );
  assert.match(
    sources[artifact],
    /not index_definition\.indisprimary[\s\S]{0,180}index_definition\.indpred is null[\s\S]{0,180}index_definition\.indexprs is null/,
    `Falta descartar índice request_id primario, parcial o de expresión en ${artifact}`,
  );
  assert.match(
    sources[artifact],
    /index_definition\.indnkeyatts=1[\s\S]*?='request_id'/,
    `Falta verificar la única clave request_id en ${artifact}`,
  );
}
for (const trigger of [
  "guard_admin_auth_operation_b3a",
  "guard_admin_auth_operation_truncate_b3a",
]) {
  assert.ok(sources.migration.includes(`create trigger ${trigger}`), `Falta trigger exacto: ${trigger}`);
  assert.ok(sources.verify.includes(trigger), `Falta verificar trigger exacto: ${trigger}`);
  assert.ok(sources.rollback.includes(trigger), `Falta resguardar trigger exacto: ${trigger}`);
}
for (const artifact of ["migration", "verify", "rollback"]) {
  assert.match(
    sources[artifact],
    /requested_at:now\(\)[\s\S]{0,180}updated_at:now\(\)/,
    `Falta contrato exacto de defaults del ledger en ${artifact}`,
  );
  assert.match(
    sources[artifact],
    /admin_auth_operations_requested_by_profile_id_fkey[\s\S]*public\.profiles'::regclass::oid,'id','a','r'/,
    `Falta mapa FK exacto del ledger en ${artifact}`,
  );
  assert.match(
    sources[artifact],
    /CREATE UNIQUE INDEX admin_auth_operations_one_nonfinal_target_uidx ON public\.admin_auth_operations USING btree \(target_profile_id\) WHERE \(status = ANY/,
    `Falta definición exacta del índice parcial en ${artifact}`,
  );
  assert.match(
    sources[artifact],
    /CREATE TRIGGER guard_admin_auth_operation_b3a BEFORE INSERT OR DELETE OR UPDATE ON admin_auth_operations FOR EACH ROW EXECUTE FUNCTION guard_admin_auth_operation_b3a\(\)/,
    `Falta definición exacta del trigger fila en ${artifact}`,
  );
}
for (const checkDefinition of [
  /constraint admin_auth_operations_operation_check check \(operation_code in \('deactivate','reactivate'\)\)/,
  /constraint admin_auth_operations_status_check check \(status in \('open','processing','retryable_failure','succeeded','terminal_failure'\)\)/,
  /constraint admin_auth_operations_stage_check check \(completed_stage in \('prepared','profile_suspended','auth_synchronized','completed'\)\)/,
  /constraint admin_auth_operations_reason_check check \(/,
  /constraint admin_auth_operations_attempt_check check \(attempt_count>=0\)/,
  /constraint admin_auth_operations_error_check check \(/,
  /constraint admin_auth_operations_stage_operation_check check \(/,
  /constraint admin_auth_operations_evidence_check check \(/,
  /constraint admin_auth_operations_timestamp_check check \(/,
]) {
  assert.match(sources.migration, checkDefinition, `Falta definición CHECK exacta: ${checkDefinition}`);
}
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
assert.match(
  prepareBody,
  /if requested_transition is null\s+or requested_transition not in \('deactivate','reactivate'\) then\s+raise exception 'sitaa_account_lifecycle_invalid_transition'\s+using errcode='22023';/,
  "La transición pública debe rechazar NULL y sólo aceptar valores exactos en minúsculas",
);
assert.doesNotMatch(
  prepareBody,
  /\b(lower|btrim|trim)\s*\(\s*requested_transition/i,
  "La transición no debe normalizarse, recortarse ni convertirse a minúsculas",
);

function extractFunctionBody(source, name) {
  const start = source.indexOf(`create function public.${name}`);
  const bodyStart = source.indexOf("as $function$", start);
  const bodyEnd = source.indexOf("$function$;", bodyStart + 1);
  assert.ok(start >= 0 && bodyStart > start && bodyEnd > bodyStart, `No se pudo extraer cuerpo de ${name}`);
  return source.slice(bodyStart + "as $function$".length, bodyEnd);
}
function assertOrderedMarkers(source, markers, label) {
  let cursor = 0;
  for (const marker of markers) {
    const position = source.indexOf(marker, cursor);
    assert.ok(position >= cursor, `${label}: falta o está fuera de orden: ${marker}`);
    cursor = position + marker.length;
  }
}
const exactB1CallerCheck =
  "caller_profile_id is null or not public.is_exact_b1_account_admin_profile_b2b(caller_profile_id)";
const exactB1ActorCheck =
  "actor_id is null or not public.is_exact_b1_account_admin_profile_b2b(actor_id)";
const exactB1ActorRecheck =
  "not public.is_exact_b1_account_admin_profile_b2b(actor_id)";
const prepareOrder = [
  exactB1ActorCheck,
  "pg_advisory_xact_lock",
  exactB1ActorRecheck,
  "operation.request_id=$4 for update",
];
const claimOrder = [
  "sitaa_service_boundary_required",
  exactB1CallerCheck,
  "pg_advisory_xact_lock",
  "for update",
  exactB1CallerCheck,
  "operation_row.status in ('succeeded','terminal_failure')",
  "operation_row.status='processing'",
  "update public.admin_auth_operations",
];
const recordOrder = [
  "sitaa_service_boundary_required",
  exactB1CallerCheck,
  "requested_result is null",
  "claimed_attempt_count is null",
  "pg_advisory_xact_lock",
  "for update",
  exactB1CallerCheck,
  "claimed_attempt_count<>operation_row.attempt_count",
  "insert into public.admin_audit_events",
  "update public.admin_auth_operations",
];
const finalizeOrder = [
  exactB1ActorCheck,
  "pg_advisory_xact_lock",
  "for update",
  exactB1ActorRecheck,
  "operation_row.status='succeeded'",
  "sitaa_auth_operation_not_ready_to_finalize",
  "transition_admin_account_lifecycle_b2b",
  "update public.admin_auth_operations",
];
const mutableAuthorizationOrders = [
  ["prepare", extractFunctionBody(sources.migration, "prepare_admin_account_auth_lifecycle_b3a"), prepareOrder],
  ["claim", extractFunctionBody(sources.migration, "claim_admin_auth_operation_b3a"), claimOrder],
  ["record", extractFunctionBody(sources.migration, "record_admin_auth_operation_result_b3a"), recordOrder],
  ["finalize", extractFunctionBody(sources.migration, "finalize_admin_account_auth_reactivation_b3a"), finalizeOrder],
];
for (const [label, body, markers] of mutableAuthorizationOrders) {
  assertOrderedMarkers(body, markers, `orden ${label}`);
}
const guardBody = extractFunctionBody(sources.migration, "guard_admin_auth_operation_b3a");
const recordBody = extractFunctionBody(sources.migration, "record_admin_auth_operation_result_b3a");
const evidenceConstraint = sliceBetween(
  sources.migration,
  "constraint admin_auth_operations_evidence_check check (",
  "constraint admin_auth_operations_timestamp_check check (",
  "matriz CHECK de evidencia",
);
for (const body of [guardBody, recordBody, evidenceConstraint]) {
  assert.match(body, /database_finalize_pending/);
  assert.match(body, /operation_code='reactivate'[\s\S]*completed_stage='auth_synchronized'/);
  assert.match(body, /auth_synchronized_at is not null[\s\S]*database_finalize_pending/);
  assert.match(body, /auth_temporarily_unavailable[\s\S]*auth_rate_limited[\s\S]*auth_user_not_found[\s\S]*auth_update_rejected[\s\S]*unsupported_auth_contract/);
}
for (const body of [guardBody, recordBody]) {
  assert.match(body, /sitaa_auth_operation_error_stage_conflict/);
}

const preAuthResultCodes = new Set([
  "auth_temporarily_unavailable", "auth_rate_limited", "auth_user_not_found",
  "auth_update_rejected", "unsupported_auth_contract",
]);
const terminalResultCodes = new Set([
  "auth_user_not_found", "auth_update_rejected", "unsupported_auth_contract",
]);
function acceptsStageError({ operationCode, stage, result, code, authEvidence }) {
  const initialStage = operationCode === "reactivate" ? "prepared" : "profile_suspended";
  if (result === "retryable_failure") {
    return stage === initialStage && !authEvidence && preAuthResultCodes.has(code)
      || operationCode === "reactivate" && stage === "auth_synchronized"
        && authEvidence && code === "database_finalize_pending";
  }
  if (result === "terminal_failure") {
    return stage === initialStage && !authEvidence && terminalResultCodes.has(code);
  }
  return result === "auth_succeeded" && code === null;
}
for (const operationCode of ["deactivate", "reactivate"]) {
  const initialStage = operationCode === "deactivate" ? "profile_suspended" : "prepared";
  for (const code of preAuthResultCodes) {
    assert.equal(acceptsStageError({
      operationCode, stage: initialStage, result: "retryable_failure", code, authEvidence: false,
    }), true);
  }
  assert.equal(acceptsStageError({
    operationCode, stage: initialStage, result: "retryable_failure",
    code: "database_finalize_pending", authEvidence: false,
  }), false);
}
assert.equal(acceptsStageError({
  operationCode: "reactivate", stage: "auth_synchronized", result: "retryable_failure",
  code: "database_finalize_pending", authEvidence: true,
}), true);
const forbiddenStageErrorFixtures = [
  ...[...preAuthResultCodes].map((code) => ({
    operationCode: "reactivate", stage: "auth_synchronized",
    result: "retryable_failure", code, authEvidence: true,
  })),
  {
    operationCode: "deactivate", stage: "auth_synchronized",
    result: "retryable_failure", code: "database_finalize_pending", authEvidence: true,
  },
  ...[...terminalResultCodes].map((code) => ({
    operationCode: "reactivate", stage: "auth_synchronized",
    result: "terminal_failure", code, authEvidence: true,
  })),
  ...["deactivate", "reactivate"].map((operationCode) => ({
    operationCode,
    stage: operationCode === "deactivate" ? "profile_suspended" : "prepared",
    result: "terminal_failure",
    code: "database_finalize_pending",
    authEvidence: false,
  })),
];
for (const fixture of forbiddenStageErrorFixtures) {
  assert.equal(acceptsStageError(fixture), false,
    `Cruce etapa/error prohibido aceptado: ${JSON.stringify(fixture)}`);
}
assert.match(
  sources.verify,
  /0010_verify_deactivate_pre_auth_finalize_code_unexpected[\s\S]*0010_verify_reactivate_pre_auth_finalize_code_unexpected/,
);
assert.match(sources.verify, /0010_verify_post_auth_provider_code_unexpected/);
assert.match(sources.verify, /0010_verify_post_auth_terminal_code_unexpected/);
for (const [fixture, markers, label] of [
  [
    `sitaa_service_boundary_required ${exactB1CallerCheck} pg_advisory_xact_lock for update operation_row.status in ('succeeded','terminal_failure')`,
    claimOrder,
    "segundo control ausente",
  ],
  [
    `sitaa_service_boundary_required ${exactB1CallerCheck} ${exactB1CallerCheck} pg_advisory_xact_lock for update operation_row.status in ('succeeded','terminal_failure')`,
    claimOrder,
    "segundo control antes del lock",
  ],
  [
    `sitaa_service_boundary_required ${exactB1CallerCheck} pg_advisory_xact_lock for update operation_row.status in ('succeeded','terminal_failure') ${exactB1CallerCheck}`,
    claimOrder,
    "replay antes del segundo control",
  ],
  [
    `sitaa_service_boundary_required ${exactB1CallerCheck} requested_result is null claimed_attempt_count is null pg_advisory_xact_lock for update insert into public.admin_audit_events ${exactB1CallerCheck} claimed_attempt_count<>operation_row.attempt_count update public.admin_auth_operations`,
    recordOrder,
    "auditoría antes del segundo control",
  ],
  [
    `${exactB1ActorCheck} pg_advisory_xact_lock for update update public.admin_auth_operations ${exactB1ActorRecheck} operation_row.status='succeeded' sitaa_auth_operation_not_ready_to_finalize transition_admin_account_lifecycle_b2b`,
    finalizeOrder,
    "DML antes del segundo control",
  ],
]) {
  assert.throws(() => assertOrderedMarkers(fixture, markers, `regresión ${label}`));
}
assert.match(
  sources.verify,
  /foreach transition_value in array array\[null::text,'','suspend','DEACTIVATE'\] loop/,
  "El verificador debe cubrir NULL, vacío, desconocido y mayúsculas",
);
assert.match(
  sources.verify,
  /observed_sqlstate<>'22023'[\s\S]*observed_message<>'sitaa_account_lifecycle_invalid_transition'/,
  "El verificador debe exigir mensaje y SQLSTATE canónicos para transición inválida",
);
assert.match(
  sources.verify,
  /0010_verify_invalid_transition_contract_failed/,
  "El verificador debe demostrar cero mutación tras cada transición inválida",
);
assert.match(sources.migration, /requested_result is null or requested_result not in/);
assert.match(sources.migration, /stable_error_code is null[\s\S]*retryable_failure/);
assert.doesNotMatch(
  `${sources.migration}\n${sources.verify}\n${sources.rollback}`,
  /record_admin_auth_operation_result_b3a\(uuid,uuid,text,text\)/,
  "No puede sobrevivir la firma de cuatro argumentos",
);
assert.match(
  sources.migration,
  /claimed_attempt_count is null or claimed_attempt_count<=0/,
  "El resultado debe exigir un intento positivo",
);
assert.match(
  sources.migration,
  /claimed_attempt_count<>operation_row\.attempt_count[\s\S]{0,180}sitaa_auth_operation_stale_attempt/,
  "El resultado debe cercarse contra el intento reclamado",
);
assert.match(edge, /claimed_attempt_count:\s*operation\.attemptCount/);
assert.match(edge, /attemptCount:\s*operation\.attemptCount/);
assert.match(sources.verify, /0010_verify_restore_failure_rejected_results_mutated_state/);
assert.match(sources.verify, /sitaa_auth_operation_stale_attempt/);
const stalePendingError = `sitaa_account_lifecycle_pending_target_${"forbidden"}`;
assert.equal(
  `${sources.migration}\n${sources.verify}\n${sources.rollback}\n${edge}`.includes(stalePendingError),
  false,
  "No puede sobrevivir el error pendiente obsoleto",
);
assert.match(sources.migration, /sitaa_account_lifecycle_pending_target' using errcode='P0001'/);
assert.match(sources.verify, /sqlerrm<>'sitaa_account_lifecycle_pending_target' or sqlstate<>'P0001'/);
for (const field of [
  "profile_audit_event_id",
  "auth_audit_event_id",
  "auth_synchronized_at",
  "completed_at",
]) {
  assert.match(
    sources.migration,
    new RegExp(`old\\.${field} is not null and new\\.${field} is distinct from old\\.${field}`),
    `${field} debe ser inmutable una vez establecido`,
  );
}
assert.match(sources.migration, /sitaa_auth_operation_error_stage_conflict/);
assert.match(sources.verify, /0010_verify_restore_failure_rejected_results_mutated_state/);
assert.match(sources.verify, /0010_verify_auth_audit_replacement_unexpected/);
assert.match(sources.verify, /0010_verify_profile_audit_replacement_unexpected/);
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
assert.match(edge, /if \(error\) return \{ kind: recordResultCondition\(error\) \};[\s\S]*parseSnapshot\(data, RESULT_FIELDS/);
assert.match(edge, /recordFailureResponse/);
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
  ["record_admin_auth_operation_result_b3a", "record_admin_auth_operation_result_b3a(uuid,uuid,integer,text,text)"],
  ["finalize_admin_account_auth_reactivation_b3a", "finalize_admin_account_auth_reactivation_b3a(uuid)"],
];
const finalBodyHashes = [];
for (const [name, signature] of functionSignatures) {
  const start = sources.migration.indexOf(`create function public.${name}`);
  const bodyStart = sources.migration.indexOf("as $function$", start) + "as $function$".length;
  const bodyEnd = sources.migration.indexOf("$function$;", bodyStart);
  assert.ok(start >= 0 && bodyStart >= "as $function$".length && bodyEnd > bodyStart, `No se pudo extraer ${signature}`);
  const bodyHash = crypto.createHash("md5")
    .update(sources.migration.slice(bodyStart, bodyEnd).replace(/\s+/g, ""))
    .digest("hex");
  const body = sources.migration.slice(bodyStart, bodyEnd);
  if (["prepare_admin_account_auth_lifecycle_b3a", "claim_admin_auth_operation_b3a",
    "record_admin_auth_operation_result_b3a", "finalize_admin_account_auth_reactivation_b3a"].includes(name)) {
    assert.match(body, /clock_timestamp\(\)/, `${signature} debe usar reloj de pared`);
    assert.doesNotMatch(body, /\bnow\(\)|\bcurrent_timestamp\b/i,
      `${signature} no puede usar tiempo de inicio de transacción`);
  }
  const expectedPair = `('${signature}','${bodyHash}')`;
  finalBodyHashes.push([signature, bodyHash]);
  assert.ok(sources.migration.includes(expectedPair), `Hash post-DDL desactualizado: ${signature}`);
  assert.ok(sources.verify.includes(expectedPair), `Hash de verificador desactualizado: ${signature}`);
  assert.ok(sources.rollback.includes(expectedPair), `Hash de rollback desactualizado: ${signature}`);
}
assert.match(sources.verify, /@example\.invalid/);
assert.match(sources.verify, /set local role authenticated/);
assert.match(sources.verify, /set local role service_role/);
assert.match(sources.verify, /rollback;/);
assert.doesNotMatch(sources.verify, /auth\.admin|updateUserById|SUPABASE_SERVICE_ROLE_KEY/);
const verifierRoleAudit = auditVerifierRoleIntervals(sources.verify, "verificador 0010");
assert.equal(verifierRoleAudit.counts.authenticated, 25);
assert.equal(verifierRoleAudit.counts.service_role, 13);
assert.equal(verifierRoleAudit.protectedRawReferences, 2);
assert.equal(verifierRoleAudit.allowlistedNegativeReferences, 2);
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
  "0010_verify_null_attempt_unexpected",
  "0010_verify_zero_attempt_unexpected",
  "0010_verify_null_retryable_code_unexpected",
  "0010_verify_null_terminal_code_unexpected",
  "0010_verify_success_error_code_unexpected",
  "0010_verify_deactivate_pre_auth_finalize_code_unexpected",
  "0010_verify_reactivate_pre_auth_finalize_code_unexpected",
  "0010_verify_post_auth_provider_code_unexpected",
  "0010_verify_post_auth_terminal_code_unexpected",
  "0010_verify_auth_synchronized_immediate_recovery_failed",
  "0010_verify_stale_attempt_unexpected",
  "0010_verify_terminal_after_sync_unexpected",
  "0010_verify_restore_failure_rejected_results_mutated_state",
  "0010_verify_auth_audit_replacement_unexpected",
  "0010_verify_profile_audit_replacement_unexpected",
  "0010_verify_final_operation_replay_failed",
  "0010_verify_latest_success_selection_failed",
  "0010_verify_terminal_result_failed",
  "0010_verify_failed_finalization_activated_profile",
  "0010_verify_retry_repeated_auth_stage",
  "0010_verify_lost_authority_activated_profile",
  "0010_verify_inactive_claim_unexpected",
  "0010_verify_inactive_claim_mutated_state",
  "0010_verify_inactive_record_unexpected",
  "0010_verify_inactive_record_mutated_state",
  "0010_verify_inactive_final_replay_unexpected",
  "0010_verify_inactive_claim_recovery_failed",
  "0010_verify_inactive_record_recovery_failed",
  "0010_verify_prepare_authorization_order_mismatch",
  "0010_verify_claim_authorization_order_mismatch",
  "0010_verify_record_authorization_order_mismatch",
  "0010_verify_finalize_authorization_order_mismatch",
  "0010_verify_preexisting_operational_history_changed",
  "0010_verify_delete_unexpected",
  "0010_verify_truncate_unexpected",
]) assert.ok(sources.verify.includes(marker), `Falta caso verificador: ${marker}`);

const immutable = new Map([
  ["0001_baseline_current_schema.sql", "62c8e53d794716b22cef2bd1008aa6704f8541cfc660825d4d8a538891274dfd"],
  ["0002_database_security_and_integrity.sql", "96329a10b93ad07a9da9d73764df78b4fba20bc0e1ba867685037ac6973fa536"],
  ["0003_fix_draft_temporal_lifecycle.sql", "059f0ee574015fc8f5a01631a7d6f894ffd429cfb3f790c9c858cd4cbe4d61e3"],
  ["0004_identity_registration_foundation.sql", "1a0ee8a54ecaa627c25b116189113ac84ef07b2f0f4ac60731dd64143cd0c6f5"],
  ["0005_fix_google_oauth_user_creation.sql", "89a7f8a9dce2df9e0466101c254a80a05493b93d7796bf772e6b46d7004663b5"],
  ["0006_structured_person_names.sql", "330dbd4d5a5fc5d508100ca09a3f4c989bd0e7a4ce4aadff2daaf4ab352db1f3"],
  ["0007_admin_account_directory_audit.sql", "967dccf8acabdd0955947cf42b97727e73072e1d5c7b0a8a2f574e126fce32d4"],
  ["0008_operational_account_barrier_identity_correction.sql", "b1b1917203d4243385daa4b85f45d17d5d75c64e9822bdf5372ff66c7b0bca9a"],
  ["0009_admin_account_lifecycle_transitions.sql", "c525998b028d5d0f8f7eed6803444b4a8e529e478c7846e8894227a65593b922"],
]);
for (const [file, expected] of immutable) {
  const digest = immutableTextArtifactSha256(path.join(root, "supabase/migrations", file));
  assert.equal(digest, expected, `Migración inmutable modificada: ${file}`);
}

const immutableHashRegressionBase = "begin;\n-- comentario base\nselect 1;\ncommit;\n";
const immutableHashRegressionDigest = immutableTextSha256(immutableHashRegressionBase);
assert.equal(
  immutableTextSha256(immutableHashRegressionBase.replace(/\n/g, "\r\n")),
  immutableHashRegressionDigest,
  "Los finales CRLF deben producir el mismo hash canónico que LF",
);
assert.equal(
  immutableTextSha256(immutableHashRegressionBase.replace(/\n/g, "\r")),
  immutableHashRegressionDigest,
  "Los CR solitarios deben producir el mismo hash canónico que LF",
);
for (const [label, mutated] of [
  ["token SQL", immutableHashRegressionBase.replace("select 1", "select 2")],
  ["espacio añadido", immutableHashRegressionBase.replace("select 1", "select  1")],
  ["espacio retirado", immutableHashRegressionBase.replace("select 1", "select1")],
  ["comentario añadido", immutableHashRegressionBase.replace("commit;", "-- comentario adicional\ncommit;")],
  ["comentario retirado", immutableHashRegressionBase.replace("-- comentario base\n", "")],
  ["salto final retirado", immutableHashRegressionBase.slice(0, -1)],
  ["salto final añadido", `${immutableHashRegressionBase}\n`],
  ["BOM añadido", `\uFEFF${immutableHashRegressionBase}`],
]) {
  assert.notEqual(
    immutableTextSha256(mutated),
    immutableHashRegressionDigest,
    `La regresión debe detectar cambio de contenido: ${label}`,
  );
}

assert.equal(fs.readdirSync(path.join(root, "supabase/migrations")).some((name) => /^0011_/.test(name)), false);
assert.equal(coreArtifacts.length, 16);
console.log("Immutable migration hashes:");
console.log("- canonical EOL mode: LF");
console.log(`- migrations audited: ${immutable.size}`);
console.log("- LF/CRLF equivalence regression: OK");
console.log("- lone CR/LF equivalence regression: OK");
console.log("- content mutation rejection: OK");
console.log("SHA-256 del paquete de revisión completo 0010:");
for (const relative of coreArtifacts) {
  const digest = crypto.createHash("sha256")
    .update(fs.readFileSync(path.join(root, relative)))
    .digest("hex");
  console.log(`  ${digest}  ${relative}`);
}
console.log("Matriz final de cuerpos 0010:");
for (const [signature, bodyHash] of finalBodyHashes) console.log(`  ${bodyHash}  ${signature}`);
console.log("Alineación migración/verificador/rollback: OK");
console.log("Alineación restricción/índice request_id mediante conindid: OK");
console.log("Alineación preflight independiente/embebido: OK");
console.log(`Categorías preflight conservadas: ${independentCategories.length} blocking + ${informationalCategories.length} informational`);
console.log("dangerous_default_acl independiente/embebida: idéntica y acotada");
console.log(`Fixture de plataforma default ACL: ${currentPlatformDefaultAclFixture.length} entradas -> 0 bloqueos`);
console.log(`Fixtures custom-role default ACL rechazadas: ${customDefaultAclFixtures.length}`);
console.log("Roles de ejecución distintos de postgres rechazados: current_user/session_user");
console.log("Defaults postgres/global de tabla y función permanecen bloqueantes: OK");
console.log("Defaults de secuencia excluidos del alcance 0010: OK");
console.log("Hash completo de pg_default_acl preservado; ALTER DEFAULT PRIVILEGES ausente: OK");
console.log("Orden de normalización ACL del ledger y mapas exactos de funciones: OK");
console.log("Mapas canónicos predestructivos y post-rollback: OK");
console.log("Validación total de transición, incluido NULL: OK");
console.log("Orden de locks del rollback: ledger -> auditoría -> guarda completa: OK");
console.log("Taxonomía provisional Auth sólo reintentable: OK");
console.log("Cercado por claimed_attempt_count: OK");
console.log(`Expresiones internal catalog-char auditadas: ${internalCatalogCharAudit.expressionsAudited}`);
console.log(`Casts ::text explícitos seguros: ${internalCatalogCharAudit.safeExplicitCasts}`);
console.log(`Concatenaciones internal catalog-char inseguras: ${internalCatalogCharAudit.unsafe.length}`);
for (const [label] of mutableAuthorizationOrders) {
  console.log(`Orden de autorización ${label}: OK`);
}
console.log(`Intervalos authenticated auditados: ${verifierRoleAudit.counts.authenticated}`);
console.log(`Intervalos service_role auditados: ${verifierRoleAudit.counts.service_role}`);
console.log(`Referencias protegidas encontradas: ${verifierRoleAudit.protectedRawReferences}`);
console.log(`Referencias negativas allowlisted: ${verifierRoleAudit.allowlistedNegativeReferences}`);
console.log(`Referencias no autorizadas: ${verifierRoleAudit.unauthorized.length}`);
console.log("Auditoría de cuerpos dollar-quoted:");
for (const [name, source] of Object.entries(sources)) {
  console.log(`  ${name}: ${extractDollarQuotedBodies(source, name).length}`);
}
console.log("Contrato SQL estático de 0010: OK");
