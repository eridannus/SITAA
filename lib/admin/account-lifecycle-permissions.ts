import type { AdminAccountLifecycleContext } from "@/types/admin";

export type AdminAccountLifecycleAction = "deactivate" | "reactivate" | null;

export interface AdminAccountLifecyclePresentation {
  action: AdminAccountLifecycleAction;
  showDependencyWarning: boolean;
}

export function getAdminAccountLifecyclePresentation(
  context: AdminAccountLifecycleContext | null,
): AdminAccountLifecyclePresentation {
  if (!context) return { action: null, showDependencyWarning: false };
  const canDeactivate = context.canDeactivate === true;
  const canReactivate = context.canReactivate === true;
  if (canDeactivate === canReactivate) {
    return { action: null, showDependencyWarning: false };
  }
  return {
    action: canDeactivate ? "deactivate" : "reactivate",
    showDependencyWarning:
      context.currentOrFutureAssignmentCount > 0 ||
      context.openResponsibilityCount > 0 ||
      context.openParticipationCount > 0,
  };
}
