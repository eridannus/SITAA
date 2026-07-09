"use server";

import { revalidatePath } from "next/cache";
import { createSupabaseServerClient } from "@/lib/supabase/server";
import { checkinMessageFromResult } from "@/lib/check-in/check-in-result";
import type { CheckinActionState } from "@/types/check-in";

function normalizeCode(value: string) {
  return value
    .trim()
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .toLowerCase()
    .replace(/\s+/g, "-")
    .replace(/-+/g, "-");
}

function isValidThreeWordCode(value: string) {
  return /^[a-z]+-[a-z]+-[a-z]+$/.test(value);
}

export async function submitCheckinCode(_previous: CheckinActionState, formData: FormData): Promise<CheckinActionState> {
  const source = formData.get("input_source");
  const rawInput = formData.get("checkin_input") ?? formData.get("checkin_code");
  const rawValue = typeof rawInput === "string" ? rawInput.trim() : "";
  const scannerInput = source === "scanner";
  const checkinInput = scannerInput ? rawValue : normalizeCode(rawValue);

  if (!checkinInput) return { status: "invalid", message: "Escribe el código de asistencia." };
  if (!scannerInput && !isValidThreeWordCode(checkinInput)) return { status: "invalid", message: "Escribe un código de tres palabras, usando sólo letras, guiones o espacios." };

  const supabase = await createSupabaseServerClient();
  const { data: { user } } = await supabase.auth.getUser();

  if (!user) return { status: "error", message: "Inicia sesión y vuelve a intentar el registro de asistencia." };

  const { data, error } = await supabase.rpc("check_in_activity", { checkin_input: checkinInput });
  const result = checkinMessageFromResult(data, error);
  revalidatePath("/activities");
  return result;
}
