import { createSupabaseServerClient } from "@/lib/supabase/server";
import type { RegistrationProgram } from "@/types/registration";

export async function getPublicRegistrationPrograms(): Promise<RegistrationProgram[]> {
  const supabase = await createSupabaseServerClient();
  const { data, error } = await supabase
    .from("academic_programs")
    .select("*")
    .order("name", { ascending: true });

  if (error) throw new Error("registration_programs_unavailable");

  return (data ?? [])
    .filter((program) => program.is_active !== false)
    .map((program) => ({ id: String(program.id), name: String(program.name) }));
}
