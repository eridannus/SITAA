import { createSupabaseServerClient } from "@/lib/supabase/server";
import type {
  AdminFilterOption,
  AdminIdentityCorrectionContext,
  AdminIdentityCorrectionErrorKind,
  AdminIdentityCorrectionInput,
  AdminIdentityCorrectionResult,
} from "@/types/admin";
import type { AccountKind, AccountStatus } from "@/types/sitaa";

type RpcError = { code?: string; message?: string };

export class AdminIdentityCorrectionDataError extends Error {
  constructor(public readonly kind: AdminIdentityCorrectionErrorKind) {
    super(kind);
  }
}

function includesCode(text: string, code: string) {
  return text.includes(code.toLowerCase());
}

function mappedError(error: RpcError): AdminIdentityCorrectionDataError {
  const text = `${error.code ?? ""} ${error.message ?? ""}`.toLowerCase();

  if (
    error.code === "PGRST202" ||
    error.code === "42883" ||
    text.includes("could not find the function") ||
    text.includes("does not exist")
  ) {
    return new AdminIdentityCorrectionDataError("migration_pending");
  }
  if (includesCode(text, "sitaa_identity_self_correction_forbidden")) {
    return new AdminIdentityCorrectionDataError("self_forbidden");
  }
  if (includesCode(text, "sitaa_identity_pending_target")) {
    return new AdminIdentityCorrectionDataError("pending_target");
  }
  if (includesCode(text, "sitaa_identity_invalid_name")) {
    return new AdminIdentityCorrectionDataError("invalid_name");
  }
  if (includesCode(text, "sitaa_identity_invalid_person_type")) {
    return new AdminIdentityCorrectionDataError("invalid_person_type");
  }
  if (includesCode(text, "sitaa_identity_invalid_identifier")) {
    return new AdminIdentityCorrectionDataError("invalid_identifier");
  }
  if (
    error.code === "23505" ||
    includesCode(text, "sitaa_identity_duplicate_identifier")
  ) {
    return new AdminIdentityCorrectionDataError("duplicate_identifier");
  }
  if (includesCode(text, "sitaa_identity_invalid_program")) {
    return new AdminIdentityCorrectionDataError("invalid_program");
  }
  if (includesCode(text, "sitaa_identity_technical_fields_forbidden")) {
    return new AdminIdentityCorrectionDataError("technical_fields_forbidden");
  }
  if (includesCode(text, "sitaa_identity_no_changes")) {
    return new AdminIdentityCorrectionDataError("no_changes");
  }
  if (includesCode(text, "sitaa_identity_invalid_reason")) {
    return new AdminIdentityCorrectionDataError("invalid_reason");
  }
  if (includesCode(text, "sitaa_identity_person_type_dependency")) {
    return new AdminIdentityCorrectionDataError("person_type_dependency");
  }
  if (includesCode(text, "sitaa_identity_program_dependency")) {
    return new AdminIdentityCorrectionDataError("program_dependency");
  }
  if (
    error.code === "42501" ||
    includesCode(text, "sitaa_admin_access_denied")
  ) {
    return new AdminIdentityCorrectionDataError("forbidden");
  }

  return new AdminIdentityCorrectionDataError("unavailable");
}

function firstRow<T>(data: unknown): T | null {
  return Array.isArray(data) && data.length ? (data[0] as T) : null;
}

type ContextRow = {
  target_profile_id: string;
  can_correct: boolean;
  denial_code: string | null;
  account_kind: AccountKind;
  account_status: AccountStatus;
  is_self: boolean;
  current_or_future_assignment_count: number | string;
  open_responsibility_count: number | string;
  open_participation_count: number | string;
};

export async function getAdminIdentityCorrectionContext(
  profileId: string,
): Promise<AdminIdentityCorrectionContext | null> {
  const supabase = await createSupabaseServerClient();
  const { data, error } = await supabase.rpc(
    "get_admin_identity_correction_context_b2a",
    { requested_profile_id: profileId },
  );
  if (error) throw mappedError(error);

  const row = firstRow<ContextRow>(data);
  if (!row) return null;

  return {
    targetProfileId: row.target_profile_id,
    canCorrect: row.can_correct,
    denialCode: row.denial_code,
    accountKind: row.account_kind,
    accountStatus: row.account_status,
    isSelf: row.is_self,
    currentOrFutureAssignmentCount: Number(
      row.current_or_future_assignment_count,
    ),
    openResponsibilityCount: Number(row.open_responsibility_count),
    openParticipationCount: Number(row.open_participation_count),
  };
}

type MutationRow = {
  target_profile_id: string;
  audit_event_id: string;
  changed_fields: string[] | null;
  updated_at: string;
};

export async function correctAdminAccountIdentity(
  input: AdminIdentityCorrectionInput,
): Promise<AdminIdentityCorrectionResult> {
  const supabase = await createSupabaseServerClient();
  const { data, error } = await supabase.rpc(
    "correct_admin_account_identity_b2a",
    {
      requested_profile_id: input.targetProfileId,
      requested_first_names: input.firstNames,
      requested_paternal_surname: input.paternalSurname,
      requested_maternal_surname: input.maternalSurname,
      requested_person_type: input.personType,
      requested_institutional_id_value: input.institutionalIdValue,
      requested_primary_program_id: input.primaryProgramId,
      correction_reason: input.reason,
    },
  );
  if (error) throw mappedError(error);

  const row = firstRow<MutationRow>(data);
  if (!row) throw new AdminIdentityCorrectionDataError("unavailable");

  return {
    targetProfileId: row.target_profile_id,
    auditEventId: row.audit_event_id,
    changedFields: row.changed_fields ?? [],
    updatedAt: row.updated_at,
  };
}

export async function getActiveIdentityCorrectionPrograms(): Promise<
  AdminFilterOption[]
> {
  const supabase = await createSupabaseServerClient();
  const { data, error } = await supabase
    .from("academic_programs")
    .select("id,name")
    .eq("is_active", true)
    .order("name");
  if (error) throw new AdminIdentityCorrectionDataError("unavailable");

  return (data ?? []).map((program) => ({
    value: String(program.id),
    label: String(program.name),
  }));
}
