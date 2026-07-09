import { createSupabaseServerClient } from "@/lib/supabase/server";

export async function finalizeExpiredAttendance() {
  try {
    const supabase = await createSupabaseServerClient();
    await supabase.rpc("finalize_expired_attendance");
  } catch {
    // La finalización es perezosa y no debe bloquear la carga de la página.
  }
}