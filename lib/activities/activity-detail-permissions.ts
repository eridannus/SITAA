export type ActivityDetailPermissionInput = {
  isDraft: boolean;
  isOwnDraft: boolean;
  studentOnly: boolean;
  canEditActivity: unknown;
  canUpdateActivityBase: unknown;
  canDeleteActivity: unknown;
};

export type ActivityDetailPermissions = {
  canManageParticipants: boolean;
  canManageAttendance: boolean;
  canUpdateBaseData: boolean;
  canDeleteActivityRecord: boolean;
};

export function getActivityDetailPermissions(
  input: ActivityDetailPermissionInput,
): ActivityDetailPermissions {
  const canAdministerPublishedActivity =
    !input.isDraft && !input.studentOnly && input.canEditActivity === true;

  return {
    canManageParticipants: canAdministerPublishedActivity,
    canManageAttendance: canAdministerPublishedActivity,
    canUpdateBaseData:
      input.isOwnDraft ||
      (!input.isDraft && input.canUpdateActivityBase === true),
    canDeleteActivityRecord:
      input.isOwnDraft ||
      (!input.isDraft && input.canDeleteActivity === true),
  };
}
