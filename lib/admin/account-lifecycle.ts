import "server-only";
import {
  FunctionsFetchError,
  FunctionsHttpError,
  FunctionsRelayError,
} from "@supabase/supabase-js";
import { createSupabaseServerClient } from "@/lib/supabase/server";
import type {
  AdminAccountAuthLifecycleEdgeInput,
  AdminAccountAuthLifecycleEdgeResult,
  AdminAccountLifecycleContext,
  AdminAccountLifecycleDenialCode,
  AdminAccountLifecycleErrorKind,
  AdminAccountLifecycleInput,
  AdminAccountLifecycleResult,
  AdminAuthOperationStableCode,
  AdminAuthOperationStage,
  AdminAuthOperationStatus,
} from "@/types/admin";
import type { AccountStatus } from "@/types/sitaa";

type RpcError = { code?: string; message?: string };

export class AdminAccountLifecycleDataError extends Error {
  constructor(public readonly kind: AdminAccountLifecycleErrorKind) {
    super(kind);
  }
}

function hasCode(text: string, code: string) {
  return text.includes(code.toLowerCase());
}

function isMissingRpc(error: RpcError, functionName: string) {
  const text = `${error.code ?? ""} ${error.message ?? ""}`.toLowerCase();
  return (error.code === "PGRST202" || error.code === "42883" ||
    text.includes("could not find the function") || text.includes("does not exist")) &&
    (text.includes(functionName.toLowerCase()) || error.code === "PGRST202");
}

function mappedError(error: RpcError): AdminAccountLifecycleDataError {
  const text = `${error.code ?? ""} ${error.message ?? ""}`.toLowerCase();
  if (isMissingRpc(error, "get_admin_account_lifecycle_context_b2b")) {
    return new AdminAccountLifecycleDataError("migration_pending");
  }
  if (hasCode(text, "sitaa_account_lifecycle_self_forbidden")) return new AdminAccountLifecycleDataError("self_forbidden");
  if (hasCode(text, "sitaa_account_lifecycle_target_unavailable")) return new AdminAccountLifecycleDataError("target_unavailable");
  if (hasCode(text, "sitaa_account_lifecycle_pending_target")) return new AdminAccountLifecycleDataError("pending_target");
  if (hasCode(text, "sitaa_account_lifecycle_invalid_transition")) return new AdminAccountLifecycleDataError("invalid_transition");
  if (hasCode(text, "sitaa_account_lifecycle_state_conflict") || hasCode(text, "sitaa_auth_operation_target_busy")) return new AdminAccountLifecycleDataError("state_conflict");
  if (hasCode(text, "sitaa_account_lifecycle_invalid_identity")) return new AdminAccountLifecycleDataError("invalid_identity");
  if (hasCode(text, "sitaa_account_lifecycle_auth_unconfirmed")) return new AdminAccountLifecycleDataError("auth_unconfirmed");
  if (hasCode(text, "sitaa_account_lifecycle_last_admin_forbidden")) return new AdminAccountLifecycleDataError("last_admin");
  if (hasCode(text, "sitaa_account_lifecycle_invalid_reason")) return new AdminAccountLifecycleDataError("invalid_reason");
  if (hasCode(text, "sitaa_auth_operation_final")) return new AdminAccountLifecycleDataError("terminal_failure");
  if (hasCode(text, "sitaa_admin_access_denied")) return new AdminAccountLifecycleDataError("forbidden");
  if (hasCode(text, "sitaa_service_boundary_required")) {
    return new AdminAccountLifecycleDataError("trusted_boundary_unavailable");
  }
  if (error.code === "42501") return new AdminAccountLifecycleDataError("unavailable");
  return new AdminAccountLifecycleDataError("unavailable");
}

function rows(data: unknown): unknown[] | null {
  return Array.isArray(data) ? data : null;
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function countValue(value: unknown): number | null {
  if (typeof value !== "number" && !(typeof value === "string" && /^\d+$/.test(value))) return null;
  const count = Number(value);
  return Number.isSafeInteger(count) && count >= 0 ? count : null;
}

const UUID_PATTERN = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const LIFECYCLE_DENIAL_CODES = new Set<AdminAccountLifecycleDenialCode>([
  "self_forbidden", "pending_target", "last_admin", "invalid_lifecycle",
  "invalid_identity", "auth_unconfirmed", "operation_in_progress",
]);
const OPERATION_STATUSES = new Set<AdminAuthOperationStatus>([
  "open", "processing", "retryable_failure", "succeeded", "terminal_failure",
]);
const OPERATION_STAGES = new Set<AdminAuthOperationStage>([
  "prepared", "profile_suspended", "auth_synchronized", "completed",
]);
const STABLE_ERROR_CODES = new Set<AdminAuthOperationStableCode>([
  "auth_temporarily_unavailable", "auth_rate_limited", "auth_user_not_found",
  "auth_update_rejected", "unsupported_auth_contract", "database_finalize_pending",
]);
const EDGE_COMPLETED_CODES = new Set(["account_deactivated", "account_reactivated"]);
const EDGE_TERMINAL_CODES = new Set([
  "auth_user_not_found", "auth_update_rejected", "unsupported_auth_contract",
]);
const EDGE_PENDING_WITH_OPERATION_CODES = new Set([
  "auth_temporarily_unavailable",
  "auth_rate_limited", "auth_user_not_found", "auth_update_rejected",
  "unsupported_auth_contract", "database_finalize_pending",
  "operation_processing", "operation_unavailable", "authorization_lost",
  "self_forbidden", "auth_unconfirmed",
  "state_conflict", "database_contract_rejected", "malformed_database_response",
  "result_persistence_failed",
]);
const EDGE_PENDING_WITHOUT_OPERATION_CODES = new Set([
  "trusted_boundary_unavailable", "malformed_database_response", "unexpected_failure",
]);
const EDGE_REJECTED_CODES = new Set([
  "method_not_allowed", "invalid_content_type", "request_too_large",
  "authentication_required", "invalid_json", "invalid_request", "invalid_reason",
  "invalid_mode", "authorization_lost", "request_id_conflict", "pending_target",
  "self_forbidden", "auth_unconfirmed",
  "operation_in_progress", "state_conflict", "database_contract_rejected",
]);

function isUuid(value: unknown): value is string {
  return typeof value === "string" && UUID_PATTERN.test(value);
}
function isTimestamp(value: unknown): value is string {
  return typeof value === "string" && value.trim() !== "" && Number.isFinite(Date.parse(value));
}
function isLifecycleDenialCode(value: unknown): value is AdminAccountLifecycleDenialCode {
  return typeof value === "string" && LIFECYCLE_DENIAL_CODES.has(value as AdminAccountLifecycleDenialCode);
}

function parseContextRow(value: unknown, b3aAvailable: boolean): AdminAccountLifecycleContext | null {
  if (!isRecord(value)) return null;
  const accountKind = value.account_kind;
  const accountStatus = value.account_status;
  const denialCode = value.denial_code;
  const activeExactB1AdminCount = countValue(value.active_exact_b1_admin_count);
  const currentOrFutureAssignmentCount = countValue(value.current_or_future_assignment_count);
  const openResponsibilityCount = countValue(value.open_responsibility_count);
  const openParticipationCount = countValue(value.open_participation_count);
  if (!isUuid(value.target_profile_id) || (accountKind !== "institutional" && accountKind !== "technical")
    || !["pending_registration", "active", "inactive"].includes(String(accountStatus))
    || typeof value.is_self !== "boolean" || typeof value.can_deactivate !== "boolean"
    || typeof value.can_reactivate !== "boolean" || typeof value.has_exact_b1_assignment !== "boolean"
    || (denialCode !== null && !isLifecycleDenialCode(denialCode))
    || activeExactB1AdminCount === null || currentOrFutureAssignmentCount === null
    || openResponsibilityCount === null || openParticipationCount === null
    || (value.can_deactivate && value.can_reactivate)
    || (denialCode !== null && (value.can_deactivate || value.can_reactivate))
    || (value.is_self && (value.can_deactivate || value.can_reactivate))) return null;

  let operation: Pick<AdminAccountLifecycleContext,
    "currentOperationId" | "operationCode" | "operationStatus" | "completedStage" |
    "attemptCount" | "retryable" | "lastErrorCode" | "operationUpdatedAt" |
    "canRetryOrFinalize"> = {
      currentOperationId: null, operationCode: null, operationStatus: null,
      completedStage: null, attemptCount: 0, retryable: false,
      lastErrorCode: null, operationUpdatedAt: null, canRetryOrFinalize: false,
    };
  if (b3aAvailable) {
    const attemptCount = countValue(value.attempt_count);
    if (value.b3a_available !== true || attemptCount === null
      || (value.current_operation_id !== null && !isUuid(value.current_operation_id))
      || (value.operation_code !== null && value.operation_code !== "deactivate" && value.operation_code !== "reactivate")
      || (value.operation_status !== null && (typeof value.operation_status !== "string" || !OPERATION_STATUSES.has(value.operation_status as AdminAuthOperationStatus)))
      || (value.completed_stage !== null && (typeof value.completed_stage !== "string" || !OPERATION_STAGES.has(value.completed_stage as AdminAuthOperationStage)))
      || typeof value.retryable !== "boolean" || typeof value.can_retry_or_finalize !== "boolean"
      || (value.last_error_code !== null && (typeof value.last_error_code !== "string" || !STABLE_ERROR_CODES.has(value.last_error_code as AdminAuthOperationStableCode)))
      || (value.operation_updated_at !== null && !isTimestamp(value.operation_updated_at))) return null;
    operation = {
      currentOperationId: value.current_operation_id,
      operationCode: value.operation_code,
      operationStatus: value.operation_status as AdminAuthOperationStatus | null,
      completedStage: value.completed_stage as AdminAuthOperationStage | null,
      attemptCount,
      retryable: value.retryable,
      lastErrorCode: value.last_error_code as AdminAuthOperationStableCode | null,
      operationUpdatedAt: value.operation_updated_at,
      canRetryOrFinalize: value.can_retry_or_finalize,
    };
  }
  return {
    targetProfileId: value.target_profile_id, accountKind,
    accountStatus: accountStatus as AccountStatus, isSelf: value.is_self,
    canDeactivate: value.can_deactivate, canReactivate: value.can_reactivate,
    denialCode, hasExactB1Assignment: value.has_exact_b1_assignment,
    activeExactB1AdminCount, currentOrFutureAssignmentCount,
    openResponsibilityCount, openParticipationCount, b3aAvailable, ...operation,
  };
}

async function loadContextFromRpc(profileId: string, b3a: boolean) {
  const supabase = await createSupabaseServerClient();
  const name = b3a
    ? "get_admin_account_auth_lifecycle_context_b3a"
    : "get_admin_account_lifecycle_context_b2b";
  const { data, error } = await supabase.rpc(name, { requested_profile_id: profileId });
  return { data, error };
}

export async function getAdminAccountLifecycleContext(profileId: string): Promise<AdminAccountLifecycleContext | null> {
  const b3a = await loadContextFromRpc(profileId, true);
  if (!b3a.error) {
    const resultRows = rows(b3a.data);
    if (!resultRows || resultRows.length > 1) throw new AdminAccountLifecycleDataError("unavailable");
    if (resultRows.length === 0) return null;
    const row = parseContextRow(resultRows[0], true);
    if (!row || row.targetProfileId !== profileId) throw new AdminAccountLifecycleDataError("unavailable");
    return row;
  }
  if (!isMissingRpc(b3a.error, "get_admin_account_auth_lifecycle_context_b3a")) throw mappedError(b3a.error);

  const legacy = await loadContextFromRpc(profileId, false);
  if (legacy.error) throw mappedError(legacy.error);
  const resultRows = rows(legacy.data);
  if (!resultRows || resultRows.length > 1) throw new AdminAccountLifecycleDataError("unavailable");
  if (resultRows.length === 0) return null;
  const row = parseContextRow(resultRows[0], false);
  if (!row || row.targetProfileId !== profileId) throw new AdminAccountLifecycleDataError("unavailable");
  return row;
}

type MutationRow = {
  target_profile_id: string; audit_event_id: string; previous_status: AccountStatus;
  new_status: AccountStatus; changed_fields: string[] | null; updated_at: string;
};

function parseMutationRow(value: unknown, input: AdminAccountLifecycleInput): MutationRow | null {
  if (!isRecord(value)) return null;
  const expectedPrevious = input.transition === "deactivate" ? "active" : "inactive";
  const expectedNew = input.transition === "deactivate" ? "inactive" : "active";
  const expectedChangedFields = ["account_status", "deactivated_at", "is_active"];
  if (!isUuid(value.target_profile_id) || value.target_profile_id !== input.targetProfileId
    || !isUuid(value.audit_event_id) || value.previous_status !== expectedPrevious
    || value.new_status !== expectedNew || !Array.isArray(value.changed_fields)
    || value.changed_fields.length !== expectedChangedFields.length
    || !value.changed_fields.every((field, index) => field === expectedChangedFields[index])
    || !isTimestamp(value.updated_at)) return null;
  return value as MutationRow;
}

// Compatibilidad temporal y revisada: sólo se usa cuando la base declara que el
// contrato B.3a no existe. Nunca se usa después de que B.3a está disponible.
export async function transitionAdminAccountLifecycleLegacyBeforeB3a(
  input: AdminAccountLifecycleInput,
): Promise<AdminAccountLifecycleResult> {
  const supabase = await createSupabaseServerClient();
  const { data, error } = await supabase.rpc("transition_admin_account_lifecycle_b2b", {
    requested_profile_id: input.targetProfileId,
    requested_transition: input.transition,
    transition_reason: input.reason,
  });
  if (error) throw mappedError(error);
  const resultRows = rows(data);
  if (!resultRows || resultRows.length !== 1) throw new AdminAccountLifecycleDataError("unavailable");
  const row = parseMutationRow(resultRows[0], input);
  if (!row) throw new AdminAccountLifecycleDataError("unavailable");
  return {
    targetProfileId: row.target_profile_id, auditEventId: row.audit_event_id,
    previousStatus: row.previous_status, newStatus: row.new_status,
    changedFields: row.changed_fields ?? [], updatedAt: row.updated_at,
  };
}

function parseEdgeResult(value: unknown): AdminAccountAuthLifecycleEdgeResult | null {
  if (!isRecord(value)
    || Object.keys(value).length !== 3
    || Object.keys(value).some((key) => !["code", "state", "operationId"].includes(key))
    || typeof value.code !== "string" || typeof value.state !== "string") return null;
  if (value.state === "completed" && EDGE_COMPLETED_CODES.has(value.code) && isUuid(value.operationId)) {
    return value as AdminAccountAuthLifecycleEdgeResult;
  }
  if (value.state === "terminal_failure" && EDGE_TERMINAL_CODES.has(value.code)
    && isUuid(value.operationId)) {
    return value as AdminAccountAuthLifecycleEdgeResult;
  }
  if (value.state === "pending") {
    if (isUuid(value.operationId) && EDGE_PENDING_WITH_OPERATION_CODES.has(value.code)) {
      return value as AdminAccountAuthLifecycleEdgeResult;
    }
    if (value.operationId === null && EDGE_PENDING_WITHOUT_OPERATION_CODES.has(value.code)) {
      return value as AdminAccountAuthLifecycleEdgeResult;
    }
  }
  if (value.state === "rejected" && value.operationId === null
    && EDGE_REJECTED_CODES.has(value.code)) {
    return value as AdminAccountAuthLifecycleEdgeResult;
  }
  return null;
}

export async function runAdminAccountAuthLifecycle(
  input: AdminAccountAuthLifecycleEdgeInput,
): Promise<AdminAccountAuthLifecycleEdgeResult> {
  const supabase = await createSupabaseServerClient();
  const { data, error } = await supabase.functions.invoke("admin-account-auth-lifecycle", { body: input });
  if (!error) {
    const result = parseEdgeResult(data);
    if (!result) throw new AdminAccountLifecycleDataError("unavailable");
    return result;
  }
  if (error instanceof FunctionsHttpError) {
    let httpBody: unknown;
    try {
      httpBody = await error.context.json();
    } catch {
      throw new AdminAccountLifecycleDataError("trusted_boundary_unavailable");
    }
    const result = parseEdgeResult(httpBody);
    if (!result) throw new AdminAccountLifecycleDataError("trusted_boundary_unavailable");
    return result;
  }
  if (error instanceof FunctionsRelayError || error instanceof FunctionsFetchError) {
    throw new AdminAccountLifecycleDataError("trusted_boundary_unavailable");
  }
  throw new AdminAccountLifecycleDataError("trusted_boundary_unavailable");
}
