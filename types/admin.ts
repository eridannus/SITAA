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
