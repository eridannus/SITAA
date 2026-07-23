import { createClient } from "npm:@supabase/supabase-js@2.110.1";
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

type OperationCode = "deactivate" | "reactivate";
type OperationStage = "prepared" | "profile_suspended" | "auth_synchronized" | "completed";

type ClaimedOperation = {
  operationId: string;
  targetProfileId: string;
  operationCode: OperationCode;
  completedStage: OperationStage;
  attemptCount: number;
};

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
  return Object.keys(value).every((key) => allowed.has(key)) &&
    Object.keys(value).length === allowed.size;
}

function normalizedReason(value: unknown) {
  return typeof value === "string" ? value.replace(/\s+/g, " ").trim() : "";
}

function singleRow(data: unknown): Record<string, unknown> | null {
  return Array.isArray(data) && data.length === 1 && isRecord(data[0]) ? data[0] : null;
}

function parseClaim(data: unknown): ClaimedOperation | null {
  const row = singleRow(data);
  if (!row || typeof row.operation_id !== "string" || !UUID_PATTERN.test(row.operation_id)
    || typeof row.target_profile_id !== "string" || !UUID_PATTERN.test(row.target_profile_id)
    || (row.operation_code !== "deactivate" && row.operation_code !== "reactivate")
    || !["prepared", "profile_suspended", "auth_synchronized", "completed"].includes(String(row.completed_stage))
    || !Number.isInteger(row.attempt_count) || Number(row.attempt_count) < 1) return null;
  return {
    operationId: row.operation_id,
    targetProfileId: row.target_profile_id,
    operationCode: row.operation_code,
    completedStage: row.completed_stage as OperationStage,
    attemptCount: Number(row.attempt_count),
  };
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
    const { data, error } = await userClient.rpc("prepare_admin_account_auth_lifecycle_b3a", {
      requested_profile_id: body.targetProfileId,
      requested_transition: body.transition,
      transition_reason: reason,
      request_id: body.requestId,
    });
    const prepared = singleRow(data);
    if (error || !prepared || typeof prepared.operation_id !== "string" || !UUID_PATTERN.test(prepared.operation_id)) {
      return response(error?.code === "42501" ? 403 : 409, "preparation_rejected", "rejected");
    }
    operationId = prepared.operation_id;
  } else if (body.mode === "retry") {
    if (!hasExactFields(body, RETRY_FIELDS)
      || typeof body.operationId !== "string" || !UUID_PATTERN.test(body.operationId)) {
      return response(400, "invalid_request", "rejected");
    }
    operationId = body.operationId;
  } else {
    return response(400, "invalid_mode", "rejected");
  }

  const { data: claimData, error: claimError } = await privilegedClient.rpc(
    "claim_admin_auth_operation_b3a",
    { requested_operation_id: operationId, caller_profile_id: actorProfileId },
  );
  const claim = parseClaim(claimData);
  if (claimError || !claim) return response(200, "operation_not_claimable", "pending", operationId);
  recordLog(operationId, "claimed", "operation_claimed");

  if (claim.operationCode === "reactivate" && claim.completedStage === "auth_synchronized") {
    const { error } = await userClient.rpc("finalize_admin_account_auth_reactivation_b3a", {
      requested_operation_id: operationId,
    });
    if (!error) return response(200, "account_reactivated", "completed", operationId);
    await privilegedClient.rpc("record_admin_auth_operation_result_b3a", {
      requested_operation_id: operationId,
      caller_profile_id: actorProfileId,
      requested_result: "retryable_failure",
      stable_error_code: "database_finalize_pending",
    });
    return response(200, "database_finalize_pending", "pending", operationId);
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
    await privilegedClient.rpc("record_admin_auth_operation_result_b3a", {
      requested_operation_id: operationId,
      caller_profile_id: actorProfileId,
      requested_result: authResult.result,
      stable_error_code: authResult.code,
    });
    recordLog(operationId, "auth", authResult.code);
    return response(200, authResult.code,
      authResult.result === "retryable_failure" ? "pending" : "terminal_failure", operationId);
  }

  const { error: recordError } = await privilegedClient.rpc("record_admin_auth_operation_result_b3a", {
    requested_operation_id: operationId,
    caller_profile_id: actorProfileId,
    requested_result: "auth_succeeded",
    stable_error_code: null,
  });
  if (recordError) return response(200, "result_persistence_failed", "pending", operationId);
  if (claim.operationCode === "deactivate") return response(200, "account_deactivated", "completed", operationId);

  const { error: finalizeError } = await userClient.rpc("finalize_admin_account_auth_reactivation_b3a", {
    requested_operation_id: operationId,
  });
  if (!finalizeError) return response(200, "account_reactivated", "completed", operationId);
  await privilegedClient.rpc("record_admin_auth_operation_result_b3a", {
    requested_operation_id: operationId,
    caller_profile_id: actorProfileId,
    requested_result: "retryable_failure",
    stable_error_code: "database_finalize_pending",
  });
  return response(200, "database_finalize_pending", "pending", operationId);
}

Deno.serve((request) => main(request).catch(() => response(500, "unexpected_failure", "pending")));
