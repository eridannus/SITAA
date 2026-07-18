import { redirect } from "next/navigation";
import Link from "next/link";
import { AuthenticatedIdentity } from "@/components/authenticated-identity";
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
    <main className="mx-auto max-w-4xl px-4 py-10 sm:px-8 sm:py-14">
      <div className="sitaa-surface rounded-3xl p-6 sm:p-9">
        <Link href="/complete-registration" className="mb-6 inline-flex min-h-11 cursor-pointer items-center gap-2 rounded-lg px-2 text-sm font-bold text-[var(--sitaa-blue)] hover:bg-[var(--sitaa-blue-light)]">← Cambiar tipo de registro</Link>
        <p className="text-sm font-bold uppercase tracking-[0.2em] text-[var(--sitaa-gold-dark)]">Registro pendiente</p>
        <h1 className="mt-3 text-3xl font-bold text-[var(--sitaa-blue-dark)]">Completar registro de {isStudent ? "alumno" : "profesor"}</h1>
        <p className="mt-4 leading-7 text-slate-600">Tu cuenta de Google ya fue autenticada. Captura ahora tus datos institucionales; esta información pertenece a SITAA y no se enviará a Google.</p>
        <div className="mt-6"><AuthenticatedIdentity user={user} /></div>
        <RegistrationForm personType={personType} programs={programs} />
      </div>
    </main>
  );
}
