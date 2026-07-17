import { redirect } from "next/navigation";
import { RegistrationForm } from "@/components/registration-form";
import { getRegistrationPrograms } from "@/lib/registration/programs";
import { createSupabaseServerClient } from "@/lib/supabase/server";
import type { RegistrationPersonType } from "@/types/registration";

export async function CompletionRegistrationPage({ personType }: { personType: RegistrationPersonType }) {
  const supabase = await createSupabaseServerClient();
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) redirect(`/login?error=sesion-requerida&next=/complete-registration/${personType}`);

  const { data: profile } = await supabase.from("profiles").select("*").eq("id", user.id).maybeSingle();
  if (!profile) redirect("/account-status?state=missing");
  if (profile.account_status === "active") redirect("/dashboard");
  if (profile.account_status === "inactive") redirect("/account-status?state=inactive");
  if (profile.account_status !== "pending_registration") redirect("/account-status?state=missing");

  const programs = await getRegistrationPrograms();
  const isStudent = personType === "student";
  return (
    <main className="mx-auto max-w-4xl px-5 py-16 sm:px-8 sm:py-20">
      <div className="rounded-3xl border border-slate-200 bg-white p-7 shadow-sm sm:p-10">
        <p className="text-sm font-bold uppercase tracking-[0.2em] text-emerald-700">Registro pendiente</p>
        <h1 className="mt-3 text-3xl font-bold text-emerald-950">Completar registro de {isStudent ? "alumno" : "profesor"}</h1>
        <p className="mt-4 leading-7 text-slate-600">Tu cuenta de Google ya fue autenticada. Captura ahora tus datos institucionales; esta información pertenece a SITAA y no se enviará a Google.</p>
        <RegistrationForm personType={personType} programs={programs} />
      </div>
    </main>
  );
}
