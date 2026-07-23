import { createClient, type SupabaseClient } from "npm:@supabase/supabase-js@2.110.1";
import {
  restoreAuthUser,
  suspendAuthUser,
  type AuthAdminResult,
} from "./auth-admin-adapter.ts";

const MAX_REQUEST_BYTES = 16_384;
const UUID_PATTERN =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const START_FIELDS = new Set(["mode", "targetProfileId", "transition", "reason", "requestId"]);
const RETRY_FIELDS = new Set(["mode", "operationId"]);
const STATUS_VALUES = new Set(["open", "processing", "retryable_failure", "succeeded", "terminal_failure"]);
const STAGE_VALUES = new Set(["prepared", "profile_suspended", "auth_synchronized", "completed"]);
const ERROR_VALUES = new Set([
  "auth_temporarily_unavailable", "auth_rate_limited", "auth_user_not_found",
  "auth_update_rejected", "unsupported_auth_contract", "database_finalize_pending",
]);
const PRE_AUTH_ERROR_VALUES = new Set<StableErrorCode>([
  "auth_temporarily_unavailable", "auth_rate_limited", "auth_user_not_found",
  "auth_update_rejected", "unsupported_auth_contract",
]);
const TERMINAL_ERROR_VALUES = new Set<StableErrorCode>([
  "auth_user_not_found", "auth_update_rejected", "unsupported_auth_contract",
]);

type OperationCode = "deactivate" | "reactivate";
type OperationStatus = "open" | "processing" | "retryable_failure" | "succeeded" | "terminal_failure";
type OperationStage = "prepared" | "profile_suspended" | "auth_synchronized" | "completed";
type StableErrorCode =
  | "auth_temporarily_unavailable"
  | "auth_rate_limited"
  | "auth_user_not_found"
  | "auth_update_rejected"
  | "unsupported_auth_contract"
  | "database_finalize_pending";

type OperationSnapshot = {
  operationId: string;
  targetProfileId: string;
  operationCode: OperationCode;
  status: OperationStatus;
  completedStage: OperationStage;
  attemptCount: number;
  retryable: boolean;
  lastErrorCode: StableErrorCode | null;
  updatedAt: string;
};

type ClaimedOperation = OperationSnapshot & { claimed: boolean };
type RecordResultOutcome =
  | { kind: "ok"; operation: OperationSnapshot }
  | { kind: "authorization_lost" }
  | { kind: "self_forbidden" }
  | { kind: "auth_unconfirmed" }
  | { kind: "database_contract_rejected" }
  | { kind: "stale_attempt" }
  | { kind: "state_conflict" }
  | { kind: "malformed_response" }
  | { kind: "unavailable" };

function response(status: number, code: string, state: string, operationId?: string) {
  return new Response(JSON.stringify({ code, state, operationId: operationId ?? null }), {
    status,
    headers: { "content-type": "application/json; charset=utf-8", "cache-control": "no-store" },
  });
}

function recordLog(operationId: string, phase: string, code: string) {
  console.info(JSON.stringify({ operationId, phase, code, timestamp: new Date().toISOString() }));
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function hasExactFields(value: Record<string, unknown>, allowed: Set<string>) {
  return Object.keys(value).every((key) => allowed.has(key)) && Object.keys(value).length === allowed.size;
}

function normalizedReason(value: unknown) {
  return typeof value === "string" ? value.replace(/\s+/g, " ").trim() : "";
}

function isTimestamp(value: unknown): value is string {
  return typeof value === "string" && value.length > 0 && Number.isFinite(Date.parse(value));
}

function exactSingleRow(data: unknown, fields: readonly string[]): Record<string, unknown> | null {
  if (!Array.isArray(data) || data.length !== 1 || !isRecord(data[0])) return null;
  const keys = Object.keys(data[0]);
  return keys.length === fields.length && keys.every((key) => fields.includes(key)) ? data[0] : null;
}

function initialStage(operationCode: OperationCode): OperationStage {
  return operationCode === "deactivate" ? "profile_suspended" : "prepared";
}

function hasExactSnapshotState(snapshot: OperationSnapshot) {
  const isInitialStage = snapshot.completedStage === initialStage(snapshot.operationCode);
  const isPostAuthReactivation = snapshot.operationCode === "reactivate"
    && snapshot.completedStage === "auth_synchronized";
  if (snapshot.status === "open") {
    return isInitialStage && snapshot.attemptCount === 0
      && !snapshot.retryable && snapshot.lastErrorCode === null;
  }
  if (snapshot.status === "processing") {
    return (isInitialStage || isPostAuthReactivation) && snapshot.attemptCount > 0
      && !snapshot.retryable && snapshot.lastErrorCode === null;
  }
  if (snapshot.status === "retryable_failure") {
    const preAuthFailure = isInitialStage
      && snapshot.lastErrorCode !== null
      && PRE_AUTH_ERROR_VALUES.has(snapshot.lastErrorCode);
    const finalizationFailure = isPostAuthReactivation
      && snapshot.lastErrorCode === "database_finalize_pending";
    return snapshot.attemptCount > 0 && snapshot.retryable
      && (preAuthFailure || finalizationFailure);
  }
  if (snapshot.status === "succeeded") {
    return snapshot.completedStage === "completed" && snapshot.attemptCount > 0
      && !snapshot.retryable && snapshot.lastErrorCode === null;
  }
  return snapshot.status === "terminal_failure"
    && isInitialStage
    && snapshot.attemptCount > 0
    && !snapshot.retryable
    && snapshot.lastErrorCode !== null
    && TERMINAL_ERROR_VALUES.has(snapshot.lastErrorCode);
}

function parseSnapshot(
  data: unknown,
  fields: readonly string[],
  expected?: {
    operationId?: string;
    targetProfileId?: string;
    operationCode?: OperationCode;
    attemptCount?: number;
  },
): OperationSnapshot | null {
  const row = exactSingleRow(data, fields);
  if (!row || typeof row.operation_id !== "string" || !UUID_PATTERN.test(row.operation_id)
    || typeof row.target_profile_id !== "string" || !UUID_PATTERN.test(row.target_profile_id)
    || (row.operation_code !== "deactivate" && row.operation_code !== "reactivate")
    || typeof row.status !== "string" || !STATUS_VALUES.has(row.status)
    || typeof row.completed_stage !== "string" || !STAGE_VALUES.has(row.completed_stage)
    || !Number.isSafeInteger(row.attempt_count) || Number(row.attempt_count) < 0
    || typeof row.retryable !== "boolean"
    || row.retryable !== (row.status === "retryable_failure")
    || (row.last_error_code !== null
      && (typeof row.last_error_code !== "string" || !ERROR_VALUES.has(row.last_error_code)))
    || !isTimestamp(row.updated_at)
    || (expected?.operationId !== undefined && row.operation_id !== expected.operationId)
    || (expected?.targetProfileId !== undefined && row.target_profile_id !== expected.targetProfileId)
    || (expected?.operationCode !== undefined && row.operation_code !== expected.operationCode)
    || (expected?.attemptCount !== undefined && row.attempt_count !== expected.attemptCount)) return null;
  const snapshot: OperationSnapshot = {
    operationId: row.operation_id,
    targetProfileId: row.target_profile_id,
    operationCode: row.operation_code,
    status: row.status as OperationStatus,
    completedStage: row.completed_stage as OperationStage,
    attemptCount: Number(row.attempt_count),
    retryable: row.retryable,
    lastErrorCode: row.last_error_code as StableErrorCode | null,
    updatedAt: row.updated_at,
  };
  return hasExactSnapshotState(snapshot) ? snapshot : null;
}

const PREPARATION_FIELDS = [
  "operation_id", "target_profile_id", "operation_code", "status", "completed_stage",
  "attempt_count", "retryable", "last_error_code", "updated_at",
] as const;
const CLAIM_FIELDS = [...PREPARATION_FIELDS, "claimed"] as const;
const RESULT_FIELDS = PREPARATION_FIELDS;
const FINALIZATION_FIELDS = [
  "operation_id", "target_profile_id", "status", "completed_stage",
  "profile_audit_event_id", "auth_audit_event_id", "completed_at",
] as const;

function parseClaim(data: unknown, expected: { operationId: string }): ClaimedOperation | null {
  const snapshot = parseSnapshot(data, CLAIM_FIELDS, expected);
  const row = exactSingleRow(data, CLAIM_FIELDS);
  if (!snapshot || !row || typeof row.claimed !== "boolean") return null;
  if (row.claimed) {
    return snapshot.status === "processing" && snapshot.attemptCount > 0
      ? { ...snapshot, claimed: true }
      : null;
  }
  return snapshot.status === "succeeded"
      || snapshot.status === "terminal_failure"
      || snapshot.status === "processing"
    ? { ...snapshot, claimed: false }
    : null;
}

function parseFinalization(data: unknown, expected: OperationSnapshot) {
  const row = exactSingleRow(data, FINALIZATION_FIELDS);
  return row
    && row.operation_id === expected.operationId
    && row.target_profile_id === expected.targetProfileId
    && row.status === "succeeded"
    && row.completed_stage === "completed"
    && typeof row.profile_audit_event_id === "string" && UUID_PATTERN.test(row.profile_audit_event_id)
    && typeof row.auth_audit_event_id === "string" && UUID_PATTERN.test(row.auth_audit_event_id)
    && isTimestamp(row.completed_at);
}

function databaseCondition(
  error: { code?: string; message?: string } | null,
  operationKnown: boolean,
) {
  const text = `${error?.code ?? ""} ${error?.message ?? ""}`.toLowerCase();
  if (text.includes("sitaa_admin_access_denied")) return "authorization_lost";
  if (text.includes("sitaa_account_lifecycle_self_forbidden")) return "self_forbidden";
  if (text.includes("sitaa_account_lifecycle_auth_unconfirmed")) return "auth_unconfirmed";
  if (text.includes("sitaa_service_boundary_required") || error?.code === "42501") {
    return operationKnown ? "database_contract_rejected" : "trusted_boundary_unavailable";
  }
  if (text.includes("sitaa_auth_operation_unavailable")) return "operation_unavailable";
  if (text.includes("sitaa_auth_operation_request_id_conflict")) return "request_id_conflict";
  if (text.includes("sitaa_account_lifecycle_pending_target")) return "pending_target";
  if (text.includes("sitaa_auth_operation_target_busy")) return "operation_in_progress";
  if (text.includes("sitaa_account_lifecycle_state_conflict")) return "state_conflict";
  return "database_contract_rejected";
}

function isPermissionCondition(error: { code?: string; message?: string } | null) {
  const text = `${error?.code ?? ""} ${error?.message ?? ""}`.toLowerCase();
  return error?.code === "42501"
    || text.includes("sitaa_admin_access_denied")
    || text.includes("sitaa_account_lifecycle_self_forbidden")
    || text.includes("sitaa_account_lifecycle_auth_unconfirmed")
    || text.includes("sitaa_service_boundary_required");
}

function recordResultCondition(error: { code?: string; message?: string } | null):
  Exclude<RecordResultOutcome["kind"], "ok" | "malformed_response"> {
  const text = `${error?.code ?? ""} ${error?.message ?? ""}`.toLowerCase();
  if (text.includes("sitaa_admin_access_denied")) {
    return "authorization_lost";
  }
  if (text.includes("sitaa_account_lifecycle_self_forbidden")) return "self_forbidden";
  if (text.includes("sitaa_account_lifecycle_auth_unconfirmed")) return "auth_unconfirmed";
  if (text.includes("sitaa_service_boundary_required") || error?.code === "42501") {
    return "database_contract_rejected";
  }
  if (text.includes("sitaa_auth_operation_stale_attempt")) return "stale_attempt";
  if (text.includes("sitaa_auth_operation_not_processing")
    || text.includes("sitaa_auth_operation_stage_conflict")
    || text.includes("sitaa_auth_operation_error_stage_conflict")) return "state_conflict";
  return "unavailable";
}

function finalResponse(operation: OperationSnapshot) {
  if (operation.status === "succeeded"
    && operation.completedStage === "completed"
    && operation.lastErrorCode === null
    && !operation.retryable) {
    return response(200, operation.operationCode === "deactivate" ? "account_deactivated" : "account_reactivated", "completed", operation.operationId);
  }
  if (operation.status === "terminal_failure"
    && operation.completedStage === initialStage(operation.operationCode)
    && operation.lastErrorCode !== null
    && TERMINAL_ERROR_VALUES.has(operation.lastErrorCode)
    && !operation.retryable) {
    return response(200, operation.lastErrorCode, "terminal_failure", operation.operationId);
  }
  return null;
}

async function recordResult(
  client: SupabaseClient,
  operation: OperationSnapshot,
  actorProfileId: string,
  requestedResult: "auth_succeeded" | "retryable_failure" | "terminal_failure",
  stableErrorCode: StableErrorCode | null,
): Promise<RecordResultOutcome> {
  const { data, error } = await client.rpc("record_admin_auth_operation_result_b3a", {
    requested_operation_id: operation.operationId,
    caller_profile_id: actorProfileId,
    claimed_attempt_count: operation.attemptCount,
    requested_result: requestedResult,
    stable_error_code: stableErrorCode,
  });
  if (error) return { kind: recordResultCondition(error) };
  const parsed = parseSnapshot(data, RESULT_FIELDS, {
    operationId: operation.operationId,
    targetProfileId: operation.targetProfileId,
    operationCode: operation.operationCode,
    attemptCount: operation.attemptCount,
  });
  if (!parsed) return { kind: "malformed_response" };
  const expected = requestedResult === "auth_succeeded"
    ? parsed.status === (operation.operationCode === "deactivate" ? "succeeded" : "processing")
      && parsed.completedStage === (operation.operationCode === "deactivate" ? "completed" : "auth_synchronized")
      && parsed.lastErrorCode === null
    : requestedResult === "retryable_failure"
      ? parsed.status === "retryable_failure"
        && parsed.completedStage === operation.completedStage
        && parsed.lastErrorCode === stableErrorCode
      : parsed.status === "terminal_failure"
        && parsed.completedStage === initialStage(operation.operationCode)
        && parsed.lastErrorCode === stableErrorCode;
  return expected ? { kind: "ok", operation: parsed } : { kind: "malformed_response" };
}

function recordFailureResponse(outcome: Exclude<RecordResultOutcome, { kind: "ok" }>, operationId: string) {
  if (outcome.kind === "authorization_lost") {
    return response(403, "authorization_lost", "pending", operationId);
  }
  if (outcome.kind === "self_forbidden" || outcome.kind === "auth_unconfirmed") {
    return response(409, outcome.kind, "pending", operationId);
  }
  if (outcome.kind === "database_contract_rejected") {
    return response(409, "database_contract_rejected", "pending", operationId);
  }
  if (outcome.kind === "stale_attempt" || outcome.kind === "state_conflict") {
    return response(200, "state_conflict", "pending", operationId);
  }
  if (outcome.kind === "malformed_response") {
    return response(200, "malformed_database_response", "pending", operationId);
  }
  return response(200, "result_persistence_failed", "pending", operationId);
}

async function finalizeReactivation(
  userClient: SupabaseClient,
  privilegedClient: SupabaseClient,
  operation: OperationSnapshot,
  actorProfileId: string,
): Promise<Response> {
  const finalized = await userClient.rpc("finalize_admin_account_auth_reactivation_b3a", {
    requested_operation_id: operation.operationId,
  });
  if (!finalized.error && parseFinalization(finalized.data, operation)) {
    return response(200, "account_reactivated", "completed", operation.operationId);
  }
  if (finalized.error && isPermissionCondition(finalized.error)) {
    const code = databaseCondition(finalized.error, true);
    return response(code === "authorization_lost" ? 403 : 409, code, "pending", operation.operationId);
  }

  // Una carrera de finalización puede haber concluido la operación. Consultar
  // mediante claim ofrece un replay autoritativo antes de persistir el fallo.
  const replay = await privilegedClient.rpc("claim_admin_auth_operation_b3a", {
    requested_operation_id: operation.operationId,
    caller_profile_id: actorProfileId,
  });
  if (replay.error && isPermissionCondition(replay.error)) {
    const code = databaseCondition(replay.error, true);
    return response(code === "authorization_lost" ? 403 : 409, code, "pending", operation.operationId);
  }
  const replayed = replay.error ? null : parseClaim(replay.data, { operationId: operation.operationId });
  const replayResponse = replayed ? finalResponse(replayed) : null;
  if (replayResponse) return replayResponse;

  if (!replayed || !replayed.claimed || replayed.status !== "processing"
    || replayed.completedStage !== "auth_synchronized") {
    return response(200, "result_persistence_failed", "pending", operation.operationId);
  }

  const persisted = await recordResult(
    privilegedClient,
    replayed,
    actorProfileId,
    "retryable_failure",
    "database_finalize_pending",
  );
  if (persisted.kind !== "ok") {
    return recordFailureResponse(persisted, operation.operationId);
  }
  if (persisted.operation.status !== "retryable_failure"
    || persisted.operation.lastErrorCode !== "database_finalize_pending") {
    return response(200, "result_persistence_failed", "pending", operation.operationId);
  }
  return response(200, "database_finalize_pending", "pending", operation.operationId);
}

async function main(request: Request): Promise<Response> {
  if (request.method !== "POST") return response(405, "method_not_allowed", "rejected");
  const contentType = request.headers.get("content-type")?.split(";", 1)[0].trim().toLowerCase();
  if (contentType !== "application/json") return response(415, "invalid_content_type", "rejected");
  const declaredLength = Number(request.headers.get("content-length") ?? "0");
  if (Number.isFinite(declaredLength) && declaredLength > MAX_REQUEST_BYTES) {
    return response(413, "request_too_large", "rejected");
  }
  const authorization = request.headers.get("authorization") ?? "";
  if (!authorization.startsWith("Bearer ")) return response(401, "authentication_required", "rejected");
  const rawBody = await request.text();
  if (new TextEncoder().encode(rawBody).byteLength > MAX_REQUEST_BYTES) {
    return response(413, "request_too_large", "rejected");
  }
  let body: unknown;
  try {
    body = JSON.parse(rawBody);
  } catch {
    return response(400, "invalid_json", "rejected");
  }
  if (!isRecord(body) || typeof body.mode !== "string") return response(400, "invalid_request", "rejected");

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!supabaseUrl || !anonKey || !serviceRoleKey) return response(503, "trusted_boundary_unavailable", "pending");

  const token = authorization.slice("Bearer ".length);
  const userClient = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authorization } },
    auth: { persistSession: false, autoRefreshToken: false, detectSessionInUrl: false },
  });
  const { data: verifiedUser, error: verificationError } = await userClient.auth.getUser(token);
  if (verificationError || !verifiedUser.user) return response(401, "authentication_required", "rejected");
  const actorProfileId = verifiedUser.user.id;
  const privilegedClient = createClient(supabaseUrl, serviceRoleKey, {
    auth: { persistSession: false, autoRefreshToken: false, detectSessionInUrl: false },
  });

  let operation: OperationSnapshot | null = null;
  let operationId: string;
  if (body.mode === "start") {
    if (!hasExactFields(body, START_FIELDS)
      || typeof body.targetProfileId !== "string" || !UUID_PATTERN.test(body.targetProfileId)
      || typeof body.requestId !== "string" || !UUID_PATTERN.test(body.requestId)
      || (body.transition !== "deactivate" && body.transition !== "reactivate")) {
      return response(400, "invalid_request", "rejected");
    }
    const reason = normalizedReason(body.reason);
    if (reason.length < 10 || reason.length > 1000) return response(400, "invalid_reason", "rejected");
    const preparedRpc = await userClient.rpc("prepare_admin_account_auth_lifecycle_b3a", {
      requested_profile_id: body.targetProfileId,
      requested_transition: body.transition,
      transition_reason: reason,
      request_id: body.requestId,
    });
    if (preparedRpc.error) {
      const code = databaseCondition(preparedRpc.error, false);
      const pending = code === "trusted_boundary_unavailable";
      return response(
        code === "authorization_lost" ? 403 : pending ? 503 : 409,
        code,
        pending ? "pending" : "rejected",
      );
    }
    operation = parseSnapshot(preparedRpc.data, PREPARATION_FIELDS, {
      targetProfileId: body.targetProfileId,
      operationCode: body.transition,
    });
    if (!operation) return response(409, "malformed_database_response", "pending");
    operationId = operation.operationId;
    const replayResponse = finalResponse(operation);
    if (replayResponse) return replayResponse;
  } else if (body.mode === "retry") {
    if (!hasExactFields(body, RETRY_FIELDS)
      || typeof body.operationId !== "string" || !UUID_PATTERN.test(body.operationId)) {
      return response(400, "invalid_request", "rejected");
    }
    operationId = body.operationId;
  } else {
    return response(400, "invalid_mode", "rejected");
  }

  const claimRpc = await privilegedClient.rpc("claim_admin_auth_operation_b3a", {
    requested_operation_id: operationId,
    caller_profile_id: actorProfileId,
  });
  if (claimRpc.error) {
    const code = databaseCondition(claimRpc.error, true);
    return response(code === "authorization_lost" ? 403 : 200, code, "pending", operationId);
  }
  const claim = parseClaim(claimRpc.data, { operationId });
  if (!claim || (operation && (claim.targetProfileId !== operation.targetProfileId
    || claim.operationCode !== operation.operationCode))) {
    return response(200, "malformed_database_response", "pending", operationId);
  }
  const claimReplay = finalResponse(claim);
  if (claimReplay) return claimReplay;
  if (!claim.claimed) return response(200, "operation_processing", "pending", operationId);
  recordLog(operationId, "claimed", "operation_claimed");

  if (claim.operationCode === "reactivate" && claim.completedStage === "auth_synchronized") {
    return finalizeReactivation(userClient, privilegedClient, claim, actorProfileId);
  }

  let authResult: AuthAdminResult;
  try {
    authResult = claim.operationCode === "deactivate"
      ? await suspendAuthUser(privilegedClient, claim.targetProfileId)
      : await restoreAuthUser(privilegedClient, claim.targetProfileId);
  } catch {
    authResult = { ok: false, result: "retryable_failure", code: "auth_temporarily_unavailable" };
  }
  if (!authResult.ok) {
    const persisted = await recordResult(
      privilegedClient,
      claim,
      actorProfileId,
      authResult.result,
      authResult.code,
    );
    if (persisted.kind !== "ok") return recordFailureResponse(persisted, operationId);
    if (persisted.operation.status !== "retryable_failure"
      || persisted.operation.lastErrorCode !== authResult.code) {
      return response(200, "result_persistence_failed", "pending", operationId);
    }
    recordLog(operationId, "auth", authResult.code);
    return response(200, authResult.code, "pending", operationId);
  }

  const persisted = await recordResult(privilegedClient, claim, actorProfileId, "auth_succeeded", null);
  if (persisted.kind !== "ok") return recordFailureResponse(persisted, operationId);
  if (claim.operationCode === "deactivate") {
    return persisted.operation.status === "succeeded" && persisted.operation.completedStage === "completed"
      ? response(200, "account_deactivated", "completed", operationId)
      : response(200, "result_persistence_failed", "pending", operationId);
  }
  if (persisted.operation.status !== "processing" || persisted.operation.completedStage !== "auth_synchronized") {
    return response(200, "result_persistence_failed", "pending", operationId);
  }
  return finalizeReactivation(userClient, privilegedClient, persisted.operation, actorProfileId);
}

Deno.serve((request) => main(request).catch(() => response(500, "unexpected_failure", "pending")));
