import type { User } from "@supabase/supabase-js";
import { createSupabaseServerClient } from "@/lib/supabase/server";
import type {
  AcademicProgram,
  ActiveRoleAssignment,
  Division,
  Profile,
  Role,
  RoleAssignment,
} from "@/types/sitaa";

export type UserContextError = "profile" | "assignments" | null;

export interface AuthenticatedUserContext {
  user: User;
  profile: Profile | null;
  primaryProgram: AcademicProgram | null;
  activeRoleAssignments: ActiveRoleAssignment[];
  error: UserContextError;
}

function isAssignmentActive(assignment: RoleAssignment, now: Date) {
  const activeStatuses = new Set(["active", "activa"]);

  if (assignment.is_active === false) {
    return false;
  }

  if (assignment.status && !activeStatuses.has(assignment.status)) {
    return false;
  }

  if (assignment.starts_at && new Date(assignment.starts_at) > now) {
    return false;
  }

  if (assignment.ends_at && new Date(assignment.ends_at) < now) {
    return false;
  }

  return true;
}

function uniqueIds(values: Array<string | null | undefined>) {
  return [...new Set(values.filter((value): value is string => Boolean(value)))];
}

export async function getAuthenticatedUserContext(): Promise<AuthenticatedUserContext | null> {
  const supabase = await createSupabaseServerClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  if (!user) {
    return null;
  }

  const { data: profileData, error: profileError } = await supabase
    .from("profiles")
    .select("*")
    .eq("id", user.id)
    .maybeSingle();

  if (profileError) {
    return {
      user,
      profile: null,
      primaryProgram: null,
      activeRoleAssignments: [],
      error: "profile",
    };
  }

  const profile = profileData as Profile | null;

  if (!profile) {
    return {
      user,
      profile: null,
      primaryProgram: null,
      activeRoleAssignments: [],
      error: null,
    };
  }

  const { data: assignmentData, error: assignmentError } = await supabase
    .from("role_assignments")
    .select("*")
    .eq("user_id", user.id);

  if (assignmentError) {
    return {
      user,
      profile,
      primaryProgram: null,
      activeRoleAssignments: [],
      error: "assignments",
    };
  }

  const assignments = (assignmentData as RoleAssignment[]).filter((assignment) =>
    isAssignmentActive(assignment, new Date()),
  );
  const roleIds = uniqueIds(assignments.map((assignment) => assignment.role_id));
  const programIds = uniqueIds([
    profile.primary_program_id,
    ...assignments.map((assignment) => assignment.program_id),
  ]);

  const [rolesResult, programsResult] = await Promise.all([
    roleIds.length
      ? supabase.from("roles").select("*").in("id", roleIds)
      : Promise.resolve({ data: [] as Role[], error: null }),
    programIds.length
      ? supabase.from("academic_programs").select("*").in("id", programIds)
      : Promise.resolve({ data: [] as AcademicProgram[], error: null }),
  ]);

  if (rolesResult.error || programsResult.error) {
    return {
      user,
      profile,
      primaryProgram: null,
      activeRoleAssignments: [],
      error: "assignments",
    };
  }

  const roles = rolesResult.data as Role[];
  const programs = programsResult.data as AcademicProgram[];
  const divisionIds = uniqueIds([
    ...assignments.map((assignment) => assignment.division_id),
    ...programs.map((program) => program.division_id),
  ]);
  const divisionsResult = divisionIds.length
    ? await supabase.from("divisions").select("*").in("id", divisionIds)
    : { data: [] as Division[], error: null };

  if (divisionsResult.error) {
    return {
      user,
      profile,
      primaryProgram: null,
      activeRoleAssignments: [],
      error: "assignments",
    };
  }

  const divisions = divisionsResult.data as Division[];
  const roleById = new Map(roles.map((role) => [role.id, role]));
  const programById = new Map(programs.map((program) => [program.id, program]));
  const divisionById = new Map(divisions.map((division) => [division.id, division]));
  const activeRoleAssignments = assignments.map((assignment) => {
    const program = assignment.program_id
      ? (programById.get(assignment.program_id) ?? null)
      : null;
    const divisionId = assignment.division_id ?? program?.division_id;

    return {
      ...assignment,
      role: roleById.get(assignment.role_id) ?? null,
      program,
      division: divisionId ? (divisionById.get(divisionId) ?? null) : null,
    };
  });

  return {
    user,
    profile,
    primaryProgram: profile.primary_program_id
      ? (programById.get(profile.primary_program_id) ?? null)
      : null,
    activeRoleAssignments,
    error: null,
  };
}