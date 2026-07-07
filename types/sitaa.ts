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
  is_active: boolean;
  created_at?: string;
  updated_at?: string;
}

export interface Role {
  id: string;
  code: string;
  name: string;
  description?: string | null;
  is_active: boolean;
  created_at?: string;
  updated_at?: string;
}

export interface Profile {
  id: string;
  full_name: string | null;
  student_number?: string | null;
  employee_number?: string | null;
  institutional_email?: string | null;
  primary_program_id: string | null;
  status: string;
  created_at?: string;
  updated_at?: string;
}

export interface RoleAssignment {
  id: string;
  user_id: string;
  role_id: string;
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