import { createSupabaseServerClient } from "@/lib/supabase/server";
import type { ActivityCheckinToken } from "@/types/check-in";

type CheckinRow = Partial<ActivityCheckinToken> & {
  token?: string | null;
  direct_token?: string | null;
  code?: string | null;
  word_code?: string | null;
  short_code?: string | null;
};

function firstRow(data: unknown): CheckinRow | null {
  if (Array.isArray(data)) return (data[0] as CheckinRow | undefined) ?? null;
  return (data as CheckinRow | null) ?? null;
}

export function normalizeCheckinToken(data: unknown, activityId: string): ActivityCheckinToken | null {
  const row = firstRow(data);
  if (!row) return null;
  const secretToken = row.secret_token?.trim() || row.token?.trim() || row.direct_token?.trim();
  const threeWordCode = row.three_word_code?.trim() || row.word_code?.trim() || row.short_code?.trim() || row.code?.trim();
  if (!secretToken || !threeWordCode) return null;
  return {
    id: row.id?.trim() || secretToken,
    activity_id: row.activity_id?.trim() || activityId,
    secret_token: secretToken,
    three_word_code: threeWordCode,
    is_active: row.is_active ?? true,
    opened_at: row.opened_at ?? null,
    closed_at: row.closed_at ?? null,
  };
}

export async function getActiveActivityAttendanceCheckin(activityId: string) {
  const supabase = await createSupabaseServerClient();
  const { data, error } = await supabase.rpc("get_active_activity_attendance_checkin", {
    target_activity_id: activityId,
  });
  if (error) return null;
  return normalizeCheckinToken(data, activityId);
}
