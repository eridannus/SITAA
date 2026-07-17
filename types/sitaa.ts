export type AssignmentScope = "own" | "program" | "division" | "system";

export type ServiceArea =
  | "tutoring"
  | "advising"
  | "both"
  | "logistics"
  | "technical";

export interface Division {
  id: string;
  code: string;
  name: string;
  is_active: boolean;
  created_at?: string;
  updated_at?: string;
}

export interface AcademicProgram {
  id: string;
  division_id: string;
  code: string;
  name: string;
  is_active?: boolean;
  created_at?: string;
  updated_at?: string;
}

export interface Role {
  id: string;
  code: string;
  label?: string | null;
  name?: string | null;
  description?: string | null;
  is_active: boolean;
  created_at?: string;
  updated_at?: string;
}

export type AccountKind = "institutional" | "technical";

export type AccountStatus = "pending_registration" | "active" | "inactive";

export type PersonType = "student" | "professor";

export type InstitutionalIdType = "student_account" | "worker_number";

export interface Profile {
  id: string;
  first_names: string | null;
  paternal_surname: string | null;
  maternal_surname: string | null;
  full_name: string | null;
  email?: string | null;
  account_kind?: AccountKind;
  account_status?: AccountStatus;
  person_type: PersonType | null;
  institutional_id_type: InstitutionalIdType | null;
  institutional_id_value: string | null;
  primary_program_id: string | null;
  is_active?: boolean;
  activated_at?: string | null;
  deactivated_at?: string | null;
  created_at?: string;
  updated_at?: string;
}

export interface RoleAssignment {
  id: string;
  user_id: string;
  role_code: string;
  scope_type: AssignmentScope;
  service_area: ServiceArea;
  division_id: string | null;
  program_id: string | null;
  starts_at: string | null;
  ends_at: string | null;
  status: string | null;
  is_active?: boolean | null;
  created_at?: string;
  updated_at?: string;
}

export interface ActiveRoleAssignment extends RoleAssignment {
  role: Role | null;
  division: Division | null;
  program: AcademicProgram | null;
}
