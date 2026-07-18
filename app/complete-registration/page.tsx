import type { Metadata } from "next";
import Link from "next/link";
import { redirect } from "next/navigation";
import { AuthenticatedIdentity } from "@/components/authenticated-identity";
import { createSupabaseServerClient } from "@/lib/supabase/server";

export const dynamic = "force-dynamic";
export const metadata: Metadata = { title: "Completar registro" };

const choices = [
  { href: "/complete-registration/student", title: "Registro de alumno", description: "Completa tu número de cuenta UNAM y programa académico." },
  { href: "/complete-registration/professor", title: "Registro de profesor", description: "Completa tu número de trabajador UNAM y programa principal." },
];

export default async function CompleteRegistrationPage() {
  const supabase = await createSupabaseServerClient();
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) redirect("/login?error=sesion-requerida&next=/complete-registration");

  const { data: profile } = await supabase.from("profiles").select("*").eq("id", user.id).maybeSingle();
  if (!profile) redirect("/account-status?state=missing");
  if (profile.account_status === "active") redirect("/dashboard");
  if (profile.account_status === "inactive") redirect("/account-status?state=inactive");

  return (
    <main className="mx-auto max-w-5xl px-4 py-10 sm:px-8 sm:py-14">
      <p className="text-sm font-bold uppercase tracking-[0.2em] text-[var(--sitaa-gold-dark)]">Registro pendiente</p>
      <h1 className="mt-3 text-3xl font-bold text-[var(--sitaa-blue-dark)]">Elige cómo completar tu registro</h1>
      <p className="mt-4 max-w-2xl leading-7 text-slate-600">Tu cuenta de Google ya fue autenticada. Ahora selecciona el tipo de identidad institucional que registrarás en SITAA.</p>
      <div className="mt-6 max-w-md"><AuthenticatedIdentity user={user} /></div>
      <div className="mt-8 grid gap-5 md:grid-cols-2">
        {choices.map((choice) => (
          <Link key={choice.href} href={choice.href} className="group flex min-h-48 cursor-pointer flex-col rounded-3xl border border-slate-200 bg-white p-7 shadow-sm transition hover:border-[var(--sitaa-blue)] hover:shadow-lg">
            <h2 className="text-2xl font-bold text-slate-900">{choice.title}</h2>
            <p className="mt-4 flex-1 leading-7 text-slate-600">{choice.description}</p>
            <span className="mt-7 text-sm font-bold text-[var(--sitaa-blue)]">Continuar →</span>
          </Link>
        ))}
      </div>
    </main>
  );
}
