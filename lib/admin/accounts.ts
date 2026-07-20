import { createSupabaseServerClient } from "@/lib/supabase/server";
import type {
  AdminAccountDetail,
  AdminAccountFilters,
  AdminAccountListItem,
  AdminAccountSearchResult,
  AdminAuditHistoryItem,
  AdminFilterOption,
  AdminRoleAssignment,
} from "@/types/admin";

type DataErrorKind = "migration_pending" | "forbidden" | "not_found" | "unavailable";

export class AdminAccountDataError extends Error {
  constructor(public readonly kind: DataErrorKind) {
    super(kind);
  }
}

type RpcError = { code?: string; message?: string };

function mappedError(error: RpcError) {
  const text = `${error.code ?? ""} ${error.message ?? ""}`.toLowerCase();
  if (error.code === "42501" || text.includes("sitaa_admin_access_denied")) {
    return new AdminAccountDataError("forbidden");
  }
  if (
    error.code === "PGRST202" ||
    error.code === "42883" ||
    text.includes("could not find the function") ||
    text.includes("does not exist")
  ) {
    return new AdminAccountDataError("migration_pending");
  }
  return new AdminAccountDataError("unavailable");
}

function firstRow<T>(data: unknown): T | null {
  return Array.isArray(data) && data.length ? (data[0] as T) : null;
}

type SearchRow = {
  profile_id: string;
  first_names: string | null;
  paternal_surname: string | null;
  maternal_surname: string | null;
  full_name: string | null;
  email: string;
  account_kind: AdminAccountListItem["accountKind"];
  account_status: AdminAccountListItem["accountStatus"];
  person_type: AdminAccountListItem["personType"];
  primary_program_id: string | null;
  primary_program_name: string | null;
  institutional_id_type: AdminAccountListItem["institutionalIdType"];
  masked_institutional_id: string | null;
  current_assignment_count: number | string;
  total_count: number | string;
};

export async function searchAdminAccounts(
  filters: AdminAccountFilters,
): Promise<AdminAccountSearchResult> {
  const supabase = await createSupabaseServerClient();
  const { data, error } = await supabase.rpc("search_admin_accounts_b1", {
    search_text: filters.query || null,
    program_filter: filters.programId || null,
    account_kind_filter: filters.accountKind || null,
    account_status_filter: filters.accountStatus || null,
    person_type_filter: filters.personType || null,
    role_code_filter: filters.roleCode || null,
    service_area_filter: filters.serviceArea || null,
    scope_type_filter: filters.scopeType || null,
    page_number: filters.page,
    page_size: filters.pageSize,
  });
  if (error) throw mappedError(error);

  const rows = (Array.isArray(data) ? data : []) as SearchRow[];
  const accounts: AdminAccountListItem[] = rows.map((row) => ({
    profileId: row.profile_id,
    firstNames: row.first_names,
    paternalSurname: row.paternal_surname,
    maternalSurname: row.maternal_surname,
    fullName: row.full_name,
    email: row.email,
    accountKind: row.account_kind,
    accountStatus: row.account_status,
    personType: row.person_type,
    primaryProgramId: row.primary_program_id,
    primaryProgramName: row.primary_program_name,
    institutionalIdType: row.institutional_id_type,
    maskedInstitutionalId: row.masked_institutional_id,
    currentAssignmentCount: Number(row.current_assignment_count),
  }));
  return {
    accounts,
    total: rows.length ? Number(rows[0].total_count) : 0,
    page: filters.page,
    pageSize: filters.pageSize,
  };
}

type DetailRow = {
  profile_id: string;
  first_names: string | null;
  paternal_surname: string | null;
  maternal_surname: string | null;
  full_name: string | null;
  email: string;
  account_kind: AdminAccountDetail["accountKind"];
  account_status: AdminAccountDetail["accountStatus"];
  person_type: AdminAccountDetail["personType"];
  institutional_id_type: AdminAccountDetail["institutionalIdType"];
  institutional_id_value: string | null;
  primary_program_id: string | null;
  primary_program_name: string | null;
  activated_at: string | null;
  deactivated_at: string | null;
  auth_email_confirmed: boolean;
};

type AssignmentRow = {
  id: string;
  role_code: string;
  role_label: string;
  scope_type: AdminRoleAssignment["scopeType"];
  service_area: AdminRoleAssignment["serviceArea"];
  division_id: string | null;
  division_name: string | null;
  program_id: string | null;
  program_name: string | null;
  starts_at: string;
  ends_at: string | null;
  is_active: boolean;
  assigned_by: string | null;
  created_at: string;
  presentation_status: AdminRoleAssignment["presentationStatus"];
};

type AuditRow = {
  id: string;
  actor_profile_id: string;
  actor_display_name: string | null;
  target_profile_id: string;
  action_code: string;
  outcome: AdminAuditHistoryItem["outcome"];
  reason: string | null;
  role_assignment_id: string | null;
  occurred_at: string;
};

export async function getAdminAccountRecord(profileId: string) {
  const supabase = await createSupabaseServerClient();
  const [detailResult, assignmentResult, auditResult] = await Promise.all([
    supabase.rpc("get_admin_account_detail_b1", { target_profile_id: profileId }),
    supabase.rpc("get_admin_account_assignments_b1", { target_profile_id: profileId }),
    supabase.rpc("get_admin_account_audit_history_b1", {
      target_profile_id: profileId,
      result_limit: 50,
      result_offset: 0,
    }),
  ]);
  const failure = detailResult.error ?? assignmentResult.error ?? auditResult.error;
  if (failure) throw mappedError(failure);

  const row = firstRow<DetailRow>(detailResult.data);
  if (!row) throw new AdminAccountDataError("not_found");

  const detail: AdminAccountDetail = {
    profileId: row.profile_id,
    firstNames: row.first_names,
    paternalSurname: row.paternal_surname,
    maternalSurname: row.maternal_surname,
    fullName: row.full_name,
    email: row.email,
    accountKind: row.account_kind,
    accountStatus: row.account_status,
    personType: row.person_type,
    institutionalIdType: row.institutional_id_type,
    institutionalIdValue: row.institutional_id_value,
    primaryProgramId: row.primary_program_id,
    primaryProgramName: row.primary_program_name,
    activatedAt: row.activated_at,
    deactivatedAt: row.deactivated_at,
    authEmailConfirmed: row.auth_email_confirmed,
  };
  const assignments = ((assignmentResult.data ?? []) as AssignmentRow[]).map(
    (item): AdminRoleAssignment => ({
      id: item.id,
      roleCode: item.role_code,
      roleLabel: item.role_label,
      scopeType: item.scope_type,
      serviceArea: item.service_area,
      divisionId: item.division_id,
      divisionName: item.division_name,
      programId: item.program_id,
      programName: item.program_name,
      startsAt: item.starts_at,
      endsAt: item.ends_at,
      isActive: item.is_active,
      assignedBy: item.assigned_by,
      createdAt: item.created_at,
      presentationStatus: item.presentation_status,
    }),
  );
  const auditHistory = ((auditResult.data ?? []) as AuditRow[]).map(
    (item): AdminAuditHistoryItem => ({
      id: item.id,
      actorProfileId: item.actor_profile_id,
      actorDisplayName: item.actor_display_name,
      targetProfileId: item.target_profile_id,
      actionCode: item.action_code,
      outcome: item.outcome,
      reason: item.reason,
      roleAssignmentId: item.role_assignment_id,
      occurredAt: item.occurred_at,
    }),
  );
  return { detail, assignments, auditHistory };
}

export async function getAdminAccountFilterOptions(): Promise<{
  programs: AdminFilterOption[];
  roles: AdminFilterOption[];
}> {
  const supabase = await createSupabaseServerClient();
  const [programs, roles] = await Promise.all([
    supabase.from("academic_programs").select("id,name").order("name"),
    supabase.from("roles").select("code,label,sort_order").order("sort_order").order("label"),
  ]);
  if (programs.error || roles.error) throw new AdminAccountDataError("unavailable");
  return {
    programs: (programs.data ?? []).map((item) => ({ value: item.id, label: item.name })),
    roles: (roles.data ?? []).map((item) => ({ value: item.code, label: item.label })),
  };
}
