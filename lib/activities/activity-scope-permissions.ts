import type { AuthenticatedUserContext } from "@/lib/auth/get-authenticated-user-context";
import type { ActivityFormValues, ActivityScopeAccess } from "@/types/activities";
import type { AcademicProgram, Division, ServiceArea } from "@/types/sitaa";

const PROGRAM_ROLES = new Set(["program_tutoring_lead", "program_advising_lead", "program_head"]);
const CREATION_ROLES = new Set(["professor", "peer_tutor", "program_tutoring_lead", "program_advising_lead", "program_head", "division_tutoring_liaison", "technical_admin"]);

export function isStudentOnlyUser(context: AuthenticatedUserContext) {
  // La identidad procede del perfil. Las asignaciones sólo pueden ampliar las
  // capacidades de un alumno, nunca convertir por sí solas a alguien en alumno.
  if (context.profile?.account_kind !== "institutional" || context.profile.person_type !== "student") {
    return false;
  }

  return !context.activeRoleAssignments.some((item) => item.role_code !== "student");
}

export function hasActivityCreationRole(context: AuthenticatedUserContext) {
  return context.activeRoleAssignments.some((item) => CREATION_ROLES.has(item.role_code));
}

function supportsService(area: ServiceArea, serviceCode: string) {
  return area === "both" || area === serviceCode;
}

function isTargetDivision(division: Division) {
  const normalized = division.name.normalize("NFD").replace(/[\u0300-\u036f]/g, "").toLowerCase();
  return normalized.includes("diseno") && normalized.includes("edificacion");
}

export function getActivityScopeAccess(context: AuthenticatedUserContext, programs: AcademicProgram[], divisions: Division[]): ActivityScopeAccess {
  const activePrograms = programs.filter((program) => program.is_active !== false);
  const targetDivision = divisions.find(isTargetDivision) ?? null;
  const assignments = context.activeRoleAssignments;
  const isTechnicalAdmin = assignments.some((item) => item.role_code === "technical_admin");
  const liaisonDivisionIds = new Set(assignments.filter((item) => item.role_code === "division_tutoring_liaison").map((item) => item.division_id).filter((id): id is string => Boolean(id)));
  const allowedProgramIds = new Set<string>();

  if (isTechnicalAdmin && targetDivision) activePrograms.filter((program) => program.division_id === targetDivision.id).forEach((program) => allowedProgramIds.add(program.id));
  else for (const assignment of assignments) {
    if ((assignment.role_code === "professor" || assignment.role_code === "peer_tutor") && context.profile?.primary_program_id) allowedProgramIds.add(context.profile.primary_program_id);
    else if (PROGRAM_ROLES.has(assignment.role_code) && assignment.program_id) allowedProgramIds.add(assignment.program_id);
    else if (assignment.role_code === "division_tutoring_liaison" && assignment.division_id) {
      activePrograms.filter((program) => program.division_id === assignment.division_id).forEach((program) => allowedProgramIds.add(program.id));
    }
  }

  const allowedPrograms = activePrograms.filter((program) => allowedProgramIds.has(program.id));
  const canUseDivisionScope = Boolean(targetDivision && (isTechnicalAdmin || liaisonDivisionIds.has(targetDivision.id)));
  return { allowedPrograms, canUseDivisionScope, divisionScopeId: canUseDivisionScope ? targetDivision?.id ?? null : null };
}

export function canManageActivityScope(context: AuthenticatedUserContext, values: ActivityFormValues, programs: AcademicProgram[], divisionId: string) {
  const assignments = context.activeRoleAssignments;
  if (assignments.some((item) => item.role_code === "technical_admin")) return true;
  if (values.scope_type === "division") {
    return assignments.some((item) => item.role_code === "division_tutoring_liaison" && item.division_id === divisionId && supportsService(item.service_area, values.service_type_code));
  }
  const program = programs.find((item) => item.id === values.program_id);
  if (!program || program.division_id !== divisionId) return false;
  return assignments.some((item) => {
    if (item.role_code === "professor" || item.role_code === "peer_tutor") return context.profile?.primary_program_id === program.id && supportsService(item.service_area, values.service_type_code);
    if (item.role_code === "program_tutoring_lead") return item.program_id === program.id && values.service_type_code === "tutoring" && supportsService(item.service_area, values.service_type_code);
    if (item.role_code === "program_advising_lead") return item.program_id === program.id && values.service_type_code === "advising" && supportsService(item.service_area, values.service_type_code);
    if (item.role_code === "program_head") return item.program_id === program.id;
    if (item.role_code === "division_tutoring_liaison") return item.division_id === program.division_id && supportsService(item.service_area, values.service_type_code);
    return false;
  });
}
