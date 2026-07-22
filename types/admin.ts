import type {
  AccountKind,
  AccountStatus,
  AssignmentScope,
  InstitutionalIdType,
  PersonType,
  ServiceArea,
} from "@/types/sitaa";

export interface AdminAccountFilters {
  query: string;
  programId: string;
  accountKind: AccountKind | "";
  accountStatus: AccountStatus | "";
  personType: PersonType | "";
  roleCode: string;
  serviceArea: ServiceArea | "";
  scopeType: AssignmentScope | "";
  page: number;
  pageSize: number;
}

export interface AdminAccountListItem {
  profileId: string;
  firstNames: string | null;
  paternalSurname: string | null;
  maternalSurname: string | null;
  fullName: string | null;
  email: string;
  accountKind: AccountKind;
  accountStatus: AccountStatus;
  personType: PersonType | null;
  primaryProgramId: string | null;
  primaryProgramName: string | null;
  institutionalIdType: InstitutionalIdType | null;
  maskedInstitutionalId: string | null;
  currentAssignmentCount: number;
}

export interface AdminAccountSearchResult {
  accounts: AdminAccountListItem[];
  total: number;
  page: number;
  pageSize: number;
  outOfRange: boolean;
  lastPage: number;
}

export interface AdminAccountDetail {
  profileId: string;
  firstNames: string | null;
  paternalSurname: string | null;
  maternalSurname: string | null;
  fullName: string | null;
  email: string;
  accountKind: AccountKind;
  accountStatus: AccountStatus;
  personType: PersonType | null;
  institutionalIdType: InstitutionalIdType | null;
  institutionalIdValue: string | null;
  primaryProgramId: string | null;
  primaryProgramName: string | null;
  activatedAt: string | null;
  deactivatedAt: string | null;
  authEmailConfirmed: boolean;
}

export type AssignmentPresentationStatus =
  | "current"
  | "future"
  | "expired"
  | "inactive"
  | "suspended_by_account_status";

export interface AdminRoleAssignment {
  id: string;
  roleCode: string;
  roleLabel: string;
  scopeType: AssignmentScope;
  serviceArea: ServiceArea;
  divisionId: string | null;
  divisionName: string | null;
  programId: string | null;
  programName: string | null;
  startsAt: string;
  endsAt: string | null;
  isActive: boolean;
  assignedBy: string | null;
  createdAt: string;
  presentationStatus: AssignmentPresentationStatus;
}

export interface AdminAuditHistoryItem {
  id: string;
  actorProfileId: string;
  actorDisplayName: string | null;
  targetProfileId: string;
  actionCode: string;
  outcome: "success" | "failure";
  reason: string | null;
  roleAssignmentId: string | null;
  occurredAt: string;
}

export interface AdminFilterOption {
  value: string;
  label: string;
}

export interface AdminIdentityCorrectionContext {
  targetProfileId: string;
  canCorrect: boolean;
  denialCode: string | null;
  accountKind: AccountKind;
  accountStatus: AccountStatus;
  isSelf: boolean;
  currentOrFutureAssignmentCount: number;
  openResponsibilityCount: number;
  openParticipationCount: number;
}

export interface AdminIdentityCorrectionInput {
  targetProfileId: string;
  firstNames: string;
  paternalSurname: string | null;
  maternalSurname: string | null;
  personType: PersonType | null;
  institutionalIdValue: string | null;
  primaryProgramId: string | null;
  reason: string;
}

export interface AdminIdentityCorrectionResult {
  targetProfileId: string;
  auditEventId: string;
  changedFields: string[];
  updatedAt: string;
}

export type AdminIdentityCorrectionErrorKind =
  | "migration_pending"
  | "forbidden"
  | "self_forbidden"
  | "pending_target"
  | "invalid_name"
  | "invalid_person_type"
  | "invalid_identifier"
  | "duplicate_identifier"
  | "invalid_program"
  | "technical_fields_forbidden"
  | "no_changes"
  | "invalid_reason"
  | "person_type_dependency"
  | "program_dependency"
  | "unavailable";

export type AdminAccountLifecycleTransition = "deactivate" | "reactivate";

export interface AdminAccountLifecycleContext {
  targetProfileId: string;
  accountKind: AccountKind;
  accountStatus: AccountStatus;
  isSelf: boolean;
  canDeactivate: boolean;
  canReactivate: boolean;
  denialCode: string | null;
  hasExactB1Assignment: boolean;
  activeExactB1AdminCount: number;
  currentOrFutureAssignmentCount: number;
  openResponsibilityCount: number;
  openParticipationCount: number;
}

export interface AdminAccountLifecycleInput {
  targetProfileId: string;
  transition: AdminAccountLifecycleTransition;
  reason: string;
}

export interface AdminAccountLifecycleResult {
  targetProfileId: string;
  auditEventId: string;
  previousStatus: AccountStatus;
  newStatus: AccountStatus;
  changedFields: string[];
  updatedAt: string;
}

export type AdminAccountLifecycleErrorKind =
  | "migration_pending"
  | "forbidden"
  | "self_forbidden"
  | "target_unavailable"
  | "pending_target"
  | "invalid_transition"
  | "state_conflict"
  | "invalid_identity"
  | "auth_unconfirmed"
  | "last_admin"
  | "invalid_reason"
  | "unavailable";
