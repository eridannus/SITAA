import { createSupabaseServerClient } from "@/lib/supabase/server";
import type { ActivityCheckinToken } from "@/types/check-in";

type RpcError = { code?: string; message?: string; details?: string; hint?: string };

type CheckinRow = Partial<ActivityCheckinToken> & {
  token?: string | null;
  direct_token?: string | null;
  code?: string | null;
  word_code?: string | null;
  short_code?: string | null;
  code_words?: string | string[] | null;
};

function firstRow(data: unknown): CheckinRow | null {
  if (Array.isArray(data)) return (data[0] as CheckinRow | undefined) ?? null;
  return (data as CheckinRow | null) ?? null;
}

function cleanText(value: unknown) {
  return typeof value === "string" ? value.trim() : "";
}

function cleanCodeWords(value: unknown) {
  if (Array.isArray(value)) return value.map((item) => cleanText(item)).filter(Boolean).join("-");
  return cleanText(value);
}

function sanitizedDetail(error: RpcError) {
  const text = [error.message, error.details, error.hint]
    .filter(Boolean)
    .join(" ")
    .replace(/[\r\n\t]+/g, " ")
    .replace(/\s+/g, " ")
    .trim();
  if (!text) return "No fue posible consultar el código activo.";
  return text.replace(/eyJ[a-zA-Z0-9._-]+/g, "[valor oculto]").slice(0, 240);
}

export function normalizeCheckinToken(data: unknown, activityId: string): ActivityCheckinToken | null {
  const row = firstRow(data);
  if (!row) return null;
  const secretToken = cleanText(row.secret_token) || cleanText(row.token) || cleanText(row.direct_token);
  const threeWordCode =
    cleanText(row.three_word_code) ||
    cleanCodeWords(row.code_words) ||
    cleanText(row.word_code) ||
    cleanText(row.short_code) ||
    cleanText(row.code);
  if (!secretToken || !threeWordCode) return null;
  return {
    id: cleanText(row.id) || secretToken,
    activity_id: cleanText(row.activity_id) || activityId,
    secret_token: secretToken,
    three_word_code: threeWordCode,
    is_active: row.is_active ?? true,
    opened_at: row.opened_at ?? null,
    closed_at: row.closed_at ?? null,
  };
}

export async function getActiveActivityAttendanceCheckin(activityId: string): Promise<{ token: ActivityCheckinToken | null; error: string | null }> {
  const supabase = await createSupabaseServerClient();
  const { data, error } = await supabase.rpc("get_active_activity_attendance_checkin", {
    target_activity_id: activityId,
  });
  if (error) return { token: null, error: sanitizedDetail(error) };
  return { token: normalizeCheckinToken(data, activityId), error: null };
}
