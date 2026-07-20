import {
  isCurrentRoleAssignment,
  type AuthenticatedUserContext,
} from "@/lib/auth/get-authenticated-user-context";

/** Exact Phase B.1 authority. Database RPCs repeat this contract independently. */
export function canAccessAccountAdministration(
  context: AuthenticatedUserContext | null,
) {
  if (
    !context?.profile ||
    context.error ||
    context.accountStatus !== "active"
  ) {
    return false;
  }

  return context.activeRoleAssignments.some(
    (assignment) =>
      isCurrentRoleAssignment(assignment) &&
      assignment.role_code === "technical_admin" &&
      assignment.scope_type === "system" &&
      assignment.service_area === "technical" &&
      assignment.program_id === null &&
      assignment.division_id === null,
  );
}
