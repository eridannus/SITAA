import type { Metadata } from "next";
import { redirect } from "next/navigation";
import { RegistrationForm } from "@/components/registration-form";
import { getPublicRegistrationPrograms } from "@/lib/registration/programs";
import { createSupabaseServerClient } from "@/lib/supabase/server";

export const dynamic = "force-dynamic";
export const metadata: Metadata = { title: "Completar registro" };

const errorMessages: Record<string, string> = {
  identifier: "El identificador institucional ya no está disponible. Verifica el dato.",
  intent: "El intento de registro expiró o ya no es válido. Captura nuevamente tus datos.",
};

type Props = { searchParams: Promise<{ error?: string | string[] }> };

export default async function CompleteRegistrationPage({ searchParams }: Props) {
  const supabase = await createSupabaseServerClient();
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) redirect("/login?error=sesion-requerida&next=/complete-registration");

  const { data: profile } = await supabase.from("profiles").select("*").eq("id", user.id).maybeSingle();
  if (!profile) redirect("/account-status?state=missing");
  if (profile.account_status === "active") redirect("/dashboard");
  if (profile.account_status === "inactive") redirect("/account-status?state=inactive");

  const programs = await getPublicRegistrationPrograms();
  const params = await searchParams;
  const errorCode = Array.isArray(params.error) ? params.error[0] : params.error;

  return (
    <main className="mx-auto max-w-4xl px-5 py-16 sm:px-8 sm:py-20">
      <div className="rounded-3xl border border-slate-200 bg-white p-7 shadow-sm sm:p-10">
        <p className="text-sm font-bold uppercase tracking-[0.2em] text-emerald-700">Registro pendiente</p>
        <h1 className="mt-3 text-3xl font-bold text-emerald-950">Completa tu identidad institucional</h1>
        <p className="mt-4 leading-7 text-slate-600">Tu cuenta de Google ya fue autenticada. Estos datos pertenecen a SITAA y no se enviarán a Google.</p>
        {errorCode && errorMessages[errorCode] && <div role="alert" className="mt-6 rounded-xl border border-amber-200 bg-amber-50 px-4 py-3 text-sm text-amber-900">{errorMessages[errorCode]}</div>}
        <RegistrationForm programs={programs} recovery />
      </div>
    </main>
  );
}
