import type { Metadata } from "next";
import { redirect } from "next/navigation";
import { createSupabaseServerClient } from "@/lib/supabase/server";
import { logout } from "@/app/dashboard/actions";
import type { AccountStatus, Profile } from "@/types/sitaa";

export const dynamic = "force-dynamic";
export const metadata: Metadata = { title: "Estado de la cuenta" };

function effectiveStatus(profile: Profile | null): AccountStatus | "missing" {
  if (!profile) return "missing";
  if (profile.account_status) return profile.account_status;
  return profile.is_active === false ? "inactive" : "active";
}

const content = {
  pending_registration: {
    eyebrow: "Registro pendiente",
    title: "Completa tu identidad institucional",
    message: "Google ya autenticó tu cuenta. Completa los datos institucionales para entrar a SITAA.",
  },
  inactive: {
    eyebrow: "Cuenta inactiva",
    title: "Tu cuenta no está habilitada",
    message: "La cuenta está inactiva. Contacta a la persona administradora de SITAA si necesitas revisar este estado.",
  },
  missing: {
    eyebrow: "Perfil no disponible",
    title: "Tu cuenta aún no tiene un perfil SITAA",
    message: "No fue posible encontrar el perfil asociado. Contacta a la persona administradora de SITAA.",
  },
} as const;

export default async function AccountStatusPage() {
  const supabase = await createSupabaseServerClient();
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) redirect("/login?error=sesion-requerida");

  const { data } = await supabase.from("profiles").select("*").eq("id", user.id).maybeSingle();
  const status = effectiveStatus((data as Profile | null) ?? null);
  if (status === "active") redirect("/dashboard");
  if (status === "pending_registration") redirect("/complete-registration");
  const state = content[status];

  return (
    <main className="mx-auto grid min-h-[70vh] max-w-4xl place-items-center px-5 py-16 sm:px-8">
      <div className="sitaa-card w-full p-8 sm:p-12">
        <p className="text-sm font-bold uppercase tracking-[0.2em] text-amber-700">{state.eyebrow}</p>
        <h1 className="mt-4 text-3xl font-bold text-slate-900">{state.title}</h1>
        <p className="mt-5 max-w-2xl leading-7 text-slate-600">{state.message}</p>
        <p className="mt-4 break-all text-sm text-slate-500">Cuenta: {user.email}</p>
        <form action={logout} className="mt-8">
          <button type="submit" className="sitaa-secondary-action px-6">
            Cerrar sesión
          </button>
        </form>
      </div>
    </main>
  );
}
