import { createSupabaseServerClient } from "@/lib/supabase/server";
import type {
  AdminAccountLifecycleContext,
  AdminAccountLifecycleDenialCode,
  AdminAccountLifecycleErrorKind,
  AdminAccountLifecycleInput,
  AdminAccountLifecycleResult,
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

function mappedError(error: RpcError): AdminAccountLifecycleDataError {
  const text = `${error.code ?? ""} ${error.message ?? ""}`.toLowerCase();

  if (
    error.code === "PGRST202" ||
    error.code === "42883" ||
    text.includes("could not find the function") ||
    text.includes("does not exist")
  ) {
    return new AdminAccountLifecycleDataError("migration_pending");
  }
  if (hasCode(text, "sitaa_account_lifecycle_self_forbidden")) {
    return new AdminAccountLifecycleDataError("self_forbidden");
  }
  if (hasCode(text, "sitaa_account_lifecycle_target_unavailable")) {
    return new AdminAccountLifecycleDataError("target_unavailable");
  }
  if (hasCode(text, "sitaa_account_lifecycle_pending_target")) {
    return new AdminAccountLifecycleDataError("pending_target");
  }
  if (hasCode(text, "sitaa_account_lifecycle_invalid_transition")) {
    return new AdminAccountLifecycleDataError("invalid_transition");
  }
  if (hasCode(text, "sitaa_account_lifecycle_state_conflict")) {
    return new AdminAccountLifecycleDataError("state_conflict");
  }
  if (hasCode(text, "sitaa_account_lifecycle_invalid_identity")) {
    return new AdminAccountLifecycleDataError("invalid_identity");
  }
  if (hasCode(text, "sitaa_account_lifecycle_auth_unconfirmed")) {
    return new AdminAccountLifecycleDataError("auth_unconfirmed");
  }
  if (hasCode(text, "sitaa_account_lifecycle_last_admin_forbidden")) {
    return new AdminAccountLifecycleDataError("last_admin");
  }
  if (hasCode(text, "sitaa_account_lifecycle_invalid_reason")) {
    return new AdminAccountLifecycleDataError("invalid_reason");
  }
  if (error.code === "42501" || hasCode(text, "sitaa_admin_access_denied")) {
    return new AdminAccountLifecycleDataError("forbidden");
  }

  return new AdminAccountLifecycleDataError("unavailable");
}

function rows(data: unknown): unknown[] | null {
  return Array.isArray(data) ? data : null;
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function countValue(value: unknown): number | null {
  if (
    typeof value !== "number" &&
    !(typeof value === "string" && /^\d+$/.test(value))
  ) return null;
  const count = Number(value);
  return Number.isSafeInteger(count) && count >= 0 ? count : null;
}

const UUID_PATTERN =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

const LIFECYCLE_DENIAL_CODES = new Set<AdminAccountLifecycleDenialCode>([
  "self_forbidden",
  "pending_target",
  "last_admin",
  "invalid_lifecycle",
  "invalid_identity",
  "auth_unconfirmed",
]);

function isUuid(value: unknown): value is string {
  return typeof value === "string" && UUID_PATTERN.test(value);
}

function isLifecycleDenialCode(
  value: unknown,
): value is AdminAccountLifecycleDenialCode {
  return typeof value === "string" &&
    LIFECYCLE_DENIAL_CODES.has(value as AdminAccountLifecycleDenialCode);
}

function isTimestamp(value: unknown): value is string {
  return typeof value === "string" && value.trim() !== "" &&
    Number.isFinite(Date.parse(value));
}

function parseContextRow(value: unknown): AdminAccountLifecycleContext | null {
  if (!isRecord(value)) return null;
  const accountKind = value.account_kind;
  const accountStatus = value.account_status;
  const denialCode = value.denial_code;
  const activeExactB1AdminCount = countValue(value.active_exact_b1_admin_count);
  const currentOrFutureAssignmentCount = countValue(
    value.current_or_future_assignment_count,
  );
  const openResponsibilityCount = countValue(value.open_responsibility_count);
  const openParticipationCount = countValue(value.open_participation_count);
  if (
    !isUuid(value.target_profile_id) ||
    (accountKind !== "institutional" && accountKind !== "technical") ||
    !["pending_registration", "active", "inactive"].includes(
      String(accountStatus),
    ) ||
    typeof value.is_self !== "boolean" ||
    typeof value.can_deactivate !== "boolean" ||
    typeof value.can_reactivate !== "boolean" ||
    typeof value.has_exact_b1_assignment !== "boolean" ||
    (denialCode !== null && !isLifecycleDenialCode(denialCode)) ||
    activeExactB1AdminCount === null ||
    currentOrFutureAssignmentCount === null ||
    openResponsibilityCount === null ||
    openParticipationCount === null ||
    (value.can_deactivate && value.can_reactivate) ||
    (denialCode !== null && (value.can_deactivate || value.can_reactivate)) ||
    (value.is_self && (value.can_deactivate || value.can_reactivate)) ||
    (accountStatus === "pending_registration" &&
      (value.can_deactivate || value.can_reactivate)) ||
    (accountStatus === "active" && value.can_reactivate) ||
    (accountStatus === "inactive" && value.can_deactivate)
  ) return null;

  return {
    targetProfileId: value.target_profile_id,
    accountKind,
    accountStatus: accountStatus as AccountStatus,
    isSelf: value.is_self,
    canDeactivate: value.can_deactivate,
    canReactivate: value.can_reactivate,
    denialCode,
    hasExactB1Assignment: value.has_exact_b1_assignment,
    activeExactB1AdminCount,
    currentOrFutureAssignmentCount,
    openResponsibilityCount,
    openParticipationCount,
  };
}

export async function getAdminAccountLifecycleContext(
  profileId: string,
): Promise<AdminAccountLifecycleContext | null> {
  const supabase = await createSupabaseServerClient();
  const { data, error } = await supabase.rpc(
    "get_admin_account_lifecycle_context_b2b",
    { requested_profile_id: profileId },
  );
  if (error) throw mappedError(error);

  const resultRows = rows(data);
  if (!resultRows || resultRows.length > 1) {
    throw new AdminAccountLifecycleDataError("unavailable");
  }
  if (resultRows.length === 0) return null;
  const row = parseContextRow(resultRows[0]);
  if (!row || row.targetProfileId !== profileId) {
    throw new AdminAccountLifecycleDataError("unavailable");
  }
  return row;
}

type MutationRow = {
  target_profile_id: string;
  audit_event_id: string;
  previous_status: AccountStatus;
  new_status: AccountStatus;
  changed_fields: string[] | null;
  updated_at: string;
};

function parseMutationRow(
  value: unknown,
  input: AdminAccountLifecycleInput,
): MutationRow | null {
  if (!isRecord(value)) return null;
  const expectedPrevious = input.transition === "deactivate" ? "active" : "inactive";
  const expectedNew = input.transition === "deactivate" ? "inactive" : "active";
  const expectedChangedFields = [
    "account_status",
    "deactivated_at",
    "is_active",
  ];
  if (
    !isUuid(value.target_profile_id) ||
    value.target_profile_id !== input.targetProfileId ||
    !isUuid(value.audit_event_id) ||
    value.previous_status !== expectedPrevious ||
    value.new_status !== expectedNew ||
    !Array.isArray(value.changed_fields) ||
    value.changed_fields.length !== expectedChangedFields.length ||
    !value.changed_fields.every(
      (field, index) => field === expectedChangedFields[index],
    ) ||
    !isTimestamp(value.updated_at)
  ) return null;
  return value as MutationRow;
}

export async function transitionAdminAccountLifecycle(
  input: AdminAccountLifecycleInput,
): Promise<AdminAccountLifecycleResult> {
  const supabase = await createSupabaseServerClient();
  const { data, error } = await supabase.rpc(
    "transition_admin_account_lifecycle_b2b",
    {
      requested_profile_id: input.targetProfileId,
      requested_transition: input.transition,
      transition_reason: input.reason,
    },
  );
  if (error) throw mappedError(error);

  const resultRows = rows(data);
  if (!resultRows || resultRows.length !== 1) {
    throw new AdminAccountLifecycleDataError("unavailable");
  }
  const row = parseMutationRow(resultRows[0], input);
  if (!row) throw new AdminAccountLifecycleDataError("unavailable");
  return {
    targetProfileId: row.target_profile_id,
    auditEventId: row.audit_event_id,
    previousStatus: row.previous_status,
    newStatus: row.new_status,
    changedFields: row.changed_fields ?? [],
    updatedAt: row.updated_at,
  };
}
