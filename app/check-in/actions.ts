"use server";

import { revalidatePath } from "next/cache";
import { createSupabaseServerClient } from "@/lib/supabase/server";
import { checkinMessageFromResult } from "@/lib/check-in/check-in-result";
import type { CheckinActionState } from "@/types/check-in";

function normalizeCode(value: string) {
  return value.trim().replace(/\s+/g, "-").toLowerCase();
}

export async function submitCheckinCode(_previous: CheckinActionState, formData: FormData): Promise<CheckinActionState> {
  const rawCode = formData.get("checkin_code");
  const code = typeof rawCode === "string" ? normalizeCode(rawCode) : "";
  if (!code) return { status: "invalid", message: "Escribe el código de asistencia." };
  const supabase = await createSupabaseServerClient();
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) return { status: "error", message: "Inicia sesi?n y vuelve a intentar el registro de asistencia." };
  const { data, error } = await supabase.rpc("check_in_activity", { checkin_input: code });
  const result = checkinMessageFromResult(data, error);
  revalidatePath("/activities");
  return result;
}
